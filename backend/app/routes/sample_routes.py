import os
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from supabase._async.client import AsyncClient

from app.core.dependencies import get_current_user
from app.core.supabase import get_async_supabase

router = APIRouter(prefix="/samples", tags=["Samples"])

SAMPLES_DIR = Path("/samples") if Path("/samples").exists() else Path(__file__).resolve().parents[3] / "samples"

DATASETS = {
    "mock-data": "Manufacturing CPQ — POs, RFQs, product specs, CSVs",
    "kuka": "KUKA Robotics — industrial robot brochures",
    "staubli": "Staubli — connectors, robots, and fluid systems",
    "milara": "Milara — semiconductor robot spec sheets",
}

TENANT_DATASET_MAP = {
    "Kawasaki Robotics": "mock-data",
    "Kuka AG": "kuka",
    "Staubli": "staubli",
    "Milara Incorporated": "milara",
}


@router.get("/datasets")
async def list_datasets():
    result = []
    for name, description in DATASETS.items():
        dataset_path = SAMPLES_DIR / name
        if not dataset_path.exists():
            continue
        files = [f.name for f in dataset_path.iterdir() if f.is_file() and not f.name.startswith(".")]
        result.append({"name": name, "description": description, "files": files, "count": len(files)})
    return result


@router.get("/for-tenant/{tenant_name}")
async def get_dataset_for_tenant(tenant_name: str):
    dataset_id = TENANT_DATASET_MAP.get(tenant_name)
    if not dataset_id or dataset_id not in DATASETS:
        return None
    dataset_path = SAMPLES_DIR / dataset_id
    if not dataset_path.exists():
        return None
    files = [f.name for f in dataset_path.iterdir() if f.is_file() and not f.name.startswith(".")]
    return {
        "name": dataset_id,
        "description": DATASETS[dataset_id],
        "files": files,
        "count": len(files),
    }


@router.get("/for-tenant-id/{tenant_id}")
async def get_dataset_for_tenant_id(
    tenant_id: UUID,
    user=Depends(get_current_user),
    supabase: AsyncClient = Depends(get_async_supabase),
):
    tenant_row = await supabase.table("tenants").select("name").eq("id", str(tenant_id)).single().execute()
    if not tenant_row.data:
        return None
    return await get_dataset_for_tenant(tenant_row.data.get("name", ""))


@router.post("/load/{dataset_name}")
async def load_sample_dataset(
    dataset_name: str,
    tenant_id: UUID | None = Query(None, description="Tenant to load samples into (required for admin)"),
    user=Depends(get_current_user),
    supabase: AsyncClient = Depends(get_async_supabase),
):
    if dataset_name not in DATASETS:
        raise HTTPException(status_code=404, detail=f"Dataset '{dataset_name}' not found")

    dataset_path = SAMPLES_DIR / dataset_name
    if not dataset_path.exists():
        raise HTTPException(status_code=404, detail="Dataset directory not found")

    role = user["user_metadata"].get("role")

    if role == "admin":
        effective_tenant_id = str(tenant_id) if tenant_id else None
    else:
        effective_tenant_id = user["user_metadata"].get("tenant_id")

    if not effective_tenant_id:
        raise HTTPException(status_code=400, detail="No tenant_id — admin must pass ?tenant_id=")

    tenant_row = await supabase.table("tenants").select("name").eq("id", effective_tenant_id).single().execute()
    if not tenant_row.data:
        raise HTTPException(status_code=404, detail="Tenant not found")
    tenant_name = tenant_row.data.get("name")
    allowed_dataset = TENANT_DATASET_MAP.get(tenant_name)
    if allowed_dataset != dataset_name:
        raise HTTPException(
            status_code=403,
            detail=f"Dataset '{dataset_name}' is not assigned to tenant '{tenant_name}'. Use '{allowed_dataset or 'N/A'}'."
        )

    uploaded = []
    skipped = []

    for file_path in sorted(dataset_path.iterdir()):
        if not file_path.is_file() or file_path.name.startswith("."):
            continue

        storage_path = f"{effective_tenant_id}/{file_path.name}"

        try:
            file_bytes = file_path.read_bytes()
            content_type = "application/pdf" if file_path.suffix == ".pdf" else "text/csv"

            await supabase.storage.from_("documents").upload(
                storage_path,
                file_bytes,
                file_options={"content-type": content_type},
            )
            uploaded.append(file_path.name)
        except Exception as e:
            if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
                skipped.append(file_path.name)
            else:
                skipped.append(f"{file_path.name} (error: {str(e)[:80]})")

    return {
        "dataset": dataset_name,
        "uploaded": len(uploaded),
        "skipped": len(skipped),
        "files_uploaded": uploaded,
        "files_skipped": skipped,
    }
