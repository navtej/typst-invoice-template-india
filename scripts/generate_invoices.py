#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
import sys
import tempfile
from copy import deepcopy
from dataclasses import dataclass
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASE_METADATA = REPO_ROOT / "metadata.local.yaml"


class InvoiceGenerationError(Exception):
    pass


@dataclass
class InvoiceRow:
    row_number: int
    date_iso: str
    amount: Decimal
    raw: dict[str, str]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate invoice PDFs from a CSV file using the Typst template in this repository.",
    )
    parser.add_argument("csv_file", type=Path, help="CSV file containing invoice rows.")
    parser.add_argument("output_dir", type=Path, help="Directory where invoice PDFs will be written.")
    parser.add_argument(
        "--base-metadata",
        type=Path,
        default=DEFAULT_BASE_METADATA,
        help="Base YAML metadata file to clone for each invoice. Defaults to metadata.local.yaml.",
    )
    parser.add_argument(
        "--default-description",
        default="Professional services",
        help="Fallback line-item description when the CSV has no description column.",
    )
    parser.add_argument(
        "--charge-heading",
        default=None,
        help="Charge section heading to use. Defaults to the first '*Charges' section from base metadata.",
    )
    parser.add_argument(
        "--start-id",
        type=int,
        default=None,
        help="Starting invoice ID sequence when the CSV omits invoice_id.",
    )
    parser.add_argument(
        "--id-width",
        type=int,
        default=3,
        help="Zero-padding width for generated invoice IDs when invoice_id is omitted.",
    )
    return parser.parse_args()


def require_command(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise InvoiceGenerationError(f"Required command not found: {name}")
    return path


def run_command(args: list[str], *, cwd: Path | None = None, input_text: str | None = None) -> str:
    completed = subprocess.run(
        args,
        cwd=cwd,
        input=input_text,
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        stderr = completed.stderr.strip() or completed.stdout.strip()
        raise InvoiceGenerationError(stderr or f"Command failed: {' '.join(args)}")
    return completed.stdout


def load_yaml_with_ruby(path: Path) -> dict:
    ruby_script = """
require "yaml"
require "json"
puts JSON.generate(YAML.load_file(ARGV[0]))
"""
    output = run_command(["ruby", "-e", ruby_script, str(path)])
    return json.loads(output)


def ensure_iso_date(value: str, row_number: int) -> str:
    value = value.strip()
    try:
        date.fromisoformat(value)
    except ValueError as exc:
        raise InvoiceGenerationError(
            f"Row {row_number}: invalid date '{value}'. Use YYYY-MM-DD."
        ) from exc
    return value


def parse_amount(value: str, row_number: int) -> Decimal:
    value = value.strip().replace(",", "")
    try:
        return Decimal(value)
    except InvalidOperation as exc:
        raise InvoiceGenerationError(
            f"Row {row_number}: invalid amount '{value}'."
        ) from exc


def load_csv_rows(path: Path) -> list[InvoiceRow]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise InvoiceGenerationError("CSV file is empty.")
        missing = {"date", "amount"} - set(reader.fieldnames)
        if missing:
            raise InvoiceGenerationError(
                "CSV is missing required columns: " + ", ".join(sorted(missing))
            )

        rows: list[InvoiceRow] = []
        for index, row in enumerate(reader, start=2):
            if not any((value or "").strip() for value in row.values()):
                continue
            rows.append(
                InvoiceRow(
                    row_number=index,
                    date_iso=ensure_iso_date(row["date"], index),
                    amount=parse_amount(row["amount"], index),
                    raw={key: (value or "").strip() for key, value in row.items()},
                )
            )
    if not rows:
        raise InvoiceGenerationError("CSV has no invoice rows.")
    return rows


def first_charge_heading(metadata: dict) -> str:
    for key in metadata:
        if key.lower().endswith("charges"):
            return key
    return "Itemized Charges"


def decimal_to_json_number(value: Decimal) -> int | float:
    return int(value) if value == value.to_integral_value() else float(value)


def humanize_charge_date(iso_date: str) -> str:
    parsed = date.fromisoformat(iso_date)
    return f"{parsed.strftime('%B')} {parsed.day}, {parsed.year}"


def invoice_sequence_value(row: InvoiceRow, args: argparse.Namespace, base_metadata: dict, index: int) -> str:
    explicit = row.raw.get("invoice_id")
    if explicit:
        return explicit

    if args.start_id is not None:
        start_value = args.start_id
    else:
        start_value = 1
        doc_id = base_metadata.get("doc-info", {}).get("id")
        if isinstance(doc_id, dict):
            base_id = doc_id.get("id")
            if isinstance(base_id, int):
                start_value = base_id
            elif isinstance(base_id, str) and base_id.isdigit():
                start_value = int(base_id)

    return str(start_value + index).zfill(args.id_width)


def build_charge(row: InvoiceRow, args: argparse.Namespace) -> dict:
    charge = {
        "date": row.raw.get("charge_date") or humanize_charge_date(row.date_iso),
        "description": row.raw.get("description") or args.default_description,
        "price": decimal_to_json_number(row.amount),
    }

    for key in ("quantity", "qty", "hours", "rate", "tax", "discount"):
        value = row.raw.get(key)
        if not value:
            continue
        parsed = parse_amount(value, row.row_number)
        charge[key] = decimal_to_json_number(parsed)

    return charge


def apply_client_overrides(metadata: dict, row: InvoiceRow) -> None:
    client_info = metadata.setdefault("client-info", {})
    mapping = {
        "client_name": "name",
        "client_address": "address",
        "client_email": "email",
        "client_phone": "phone",
    }
    for csv_key, metadata_key in mapping.items():
        value = row.raw.get(csv_key)
        if value:
            client_info[metadata_key] = value


def build_metadata(base_metadata: dict, row: InvoiceRow, args: argparse.Namespace, index: int) -> dict:
    metadata = deepcopy(base_metadata)
    metadata.setdefault("doc-info", {})
    metadata["doc-info"]["date"] = row.date_iso

    doc_id = metadata["doc-info"].get("id")
    if isinstance(doc_id, dict):
        doc_id["id"] = invoice_sequence_value(row, args, base_metadata, index)
    elif row.raw.get("invoice_id"):
        metadata["doc-info"]["id"] = row.raw["invoice_id"]

    if row.raw.get("title"):
        metadata["doc-info"]["title"] = row.raw["title"]

    apply_client_overrides(metadata, row)

    heading = args.charge_heading or first_charge_heading(metadata)
    for key in list(metadata.keys()):
        if key.lower().endswith("charges"):
            metadata.pop(key)
    metadata[heading] = [build_charge(row, args)]
    return metadata


def copy_logo_if_needed(workspace: Path, metadata: dict, base_metadata_path: Path) -> None:
    doc_info = metadata.get("doc-info", {})
    if not doc_info.get("use-logo") or "logo-file" not in doc_info:
        return

    logo_value = str(doc_info["logo-file"])
    logo_path = Path(logo_value)
    candidates = []
    if logo_path.is_absolute():
        candidates.append(logo_path)
    else:
        candidates.append(base_metadata_path.parent / logo_path)
        candidates.append(REPO_ROOT / logo_path)

    for candidate in candidates:
        if candidate.exists():
            destination = workspace / candidate.name
            shutil.copy2(candidate, destination)
            doc_info["logo-file"] = candidate.name
            return

    raise InvoiceGenerationError(
        f"Logo file not found for doc-info.logo-file: {logo_value}"
    )


def output_filename(metadata: dict, row: InvoiceRow, index: int) -> str:
    explicit = row.raw.get("output_name")
    if explicit:
        return explicit if explicit.lower().endswith(".pdf") else f"{explicit}.pdf"

    doc_id = metadata.get("doc-info", {}).get("id")
    suffix = index + 1
    if isinstance(doc_id, dict):
        suffix = doc_id.get("id", suffix)
    elif doc_id:
        suffix = doc_id

    safe = "".join(ch if str(ch).isalnum() or ch in ("-", "_") else "-" for ch in str(suffix))
    safe = safe.strip("-") or str(index + 1)
    return f"invoice-{safe}.pdf"


def render_invoice(metadata: dict, output_path: Path, base_metadata_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="invoice-batch-") as tmpdir:
        workspace = Path(tmpdir)
        shutil.copy2(REPO_ROOT / "template.typ", workspace / "template.typ")

        main_content = """#import "template.typ": invoice-from-metadata

#let meta = json("metadata.json")
#if meta.doc-info.at("use-logo", default: false) and "logo-file" in meta.doc-info {
  meta.doc-info.insert("logo", image(meta.doc-info.at("logo-file"), height: 5em))
}
#invoice-from-metadata(meta, pre-table-body: [], apply-default-style: true)
"""
        (workspace / "main.typ").write_text(main_content, encoding="utf-8")
        (workspace / "metadata.json").write_text(
            json.dumps(metadata, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

        copy_logo_if_needed(workspace, metadata, base_metadata_path)
        run_command(["typst", "compile", "main.typ", str(output_path)], cwd=workspace)


def main() -> int:
    args = parse_args()
    require_command("typst")
    require_command("ruby")

    if not args.csv_file.exists():
        raise InvoiceGenerationError(f"CSV file not found: {args.csv_file}")
    if not args.base_metadata.exists():
        raise InvoiceGenerationError(
            f"Base metadata file not found: {args.base_metadata}. Copy metadata.yaml to metadata.local.yaml and edit it first."
        )

    base_metadata = load_yaml_with_ruby(args.base_metadata)
    rows = load_csv_rows(args.csv_file)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    generated: list[Path] = []
    for index, row in enumerate(rows):
        metadata = build_metadata(base_metadata, row, args, index)
        pdf_path = args.output_dir / output_filename(metadata, row, index)
        render_invoice(metadata, pdf_path, args.base_metadata)
        generated.append(pdf_path)
        print(f"Generated {pdf_path}")

    print(f"Done. Created {len(generated)} invoice(s) in {args.output_dir}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except InvoiceGenerationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
