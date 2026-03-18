# Sample Documents

Test data for running the Cortex pipeline end-to-end. Upload these through the frontend at `http://localhost:5173` after logging in as a tenant user.

## Datasets

### `mock-data/` — Manufacturing CPQ Documents
Purchase orders, RFQs, product specs, and CSV data with explicit cross-references (PO numbers reference RFQs, RFQs reference product specs). Best for testing FK resolution and relationship detection.

| File | Type |
|------|------|
| `PO_2024-0311_Automotive_Wheels.pdf` | Purchase Order |
| `PO_2024-0422_FastFood_Fryers.pdf` | Purchase Order |
| `RFQ_2024-011_Automotive_Wheels_Fleet.pdf` | Request for Quote |
| `RFQ_2024-012_OffRoad_Heavy_Vehicle_Wheels.pdf` | Request for Quote |
| `RFQ_2024-021_Commercial_Deep_Fryers.pdf` | Request for Quote |
| `RFQ_2024-022_Fryer_Accessories_Maintenance.pdf` | Request for Quote |
| `ProductSpec_Automotive_Wheels_v2.pdf` | Product Specification |
| `ProductSpec_Commercial_Fryers_v2.pdf` | Product Specification |
| `customers_2.csv` | Customer Data |
| `sales_data_2.csv` | Sales Data |

### `kuka/` — KUKA Robotics
Industrial robot brochures, product presentations, and welding system specs from KUKA. Good for testing unsupervised clustering across different product categories.

### `milara/` — Milara / Equipe Robotics
Semiconductor handling robot spec sheets, controller specs, and EFEM brochures. Good for testing classification of highly similar technical documents with subtle differences.

## Quick Test

1. Start the app: `npm run fresh`
2. Open `http://localhost:5173`
3. Log in as `eng@kuka.com` / `password`
4. Upload the files from `kuka/`
5. Go to Admin panel → walk through each pipeline step
