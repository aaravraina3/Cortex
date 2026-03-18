import os
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from supabase._async.client import AsyncClient

from app.core.dependencies import get_current_user
from app.core.supabase import get_async_supabase

router = APIRouter(prefix="/samples", tags=["Samples"])

SAMPLES_DIR = Path("/samples") if Path("/samples").exists() else Path(__file__).resolve().parents[3] / "samples"

DATASETS = {
    "mock-data": "Manufacturing CPQ — POs, RFQs, product specs, CSVs",
    "kuka": "KUKA Robotics — industrial robot brochures",
    "milara": "Milara — semiconductor robot spec sheets",
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


@router.post("/load/{dataset_name}")
async def load_sample_dataset(
    dataset_name: str,
    user=Depends(get_current_user),
    supabase: AsyncClient = Depends(get_async_supabase),
):
    if dataset_name not in DATASETS:
        raise HTTPException(status_code=404, detail=f"Dataset '{dataset_name}' not found")

    dataset_path = SAMPLES_DIR / dataset_name
    if not dataset_path.exists():
        raise HTTPException(status_code=404, detail=f"Dataset directory not found")

    tenant_id = user["user_metadata"].get("tenant_id")
    role = user["user_metadata"].get("role")

    if role == "admin":
        tenant_id = user["user_metadata"].get("tenant_id")
        if not tenant_id:
            raise HTTPException(status_code=400, detail="Admin must select a tenant first")

    if not tenant_id:
        raise HTTPException(status_code=400, detail="No tenant_id found")

    uploaded = []
    skipped = []

    for file_path in sorted(dataset_path.iterdir()):
        if not file_path.is_file() or file_path.name.startswith("."):
            continue

        storage_path = f"{tenant_id}/{file_path.name}"

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
