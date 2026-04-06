# Invoice Template for Typst

![](sample-use.gif)

Generates a minimalist invoice from provided company, customer and charges data. One nice upside of this template vs manually configuring an invoice is that totals are automatically calculated, reducing the chance of human error.

All required information is shown in the sample [metadata.yaml](metadata.yaml) file. Copy it to `metadata.local.yaml`, edit that local file, and then render using the MWE [main.typ](main.typ). The template now always reads `metadata.local.yaml` and Typst will error if that file does not exist.

## Features
### Locale:
Simply change the default `locale` options in your metadata, or update the respective template states before rendering.

### Typography and page styling:
Use the optional `style` section in your metadata to control `font-face`, `font-size`, `font-color`, `hyphenate`, `link-color`, `paper`, `page-margin`, and the invoice theme colors such as `accent-color`, `surface-color`, `border-color`, and `total-fill-color`.

### Billing options:
- Any metadata key ending in "charges" (case insensitive) will be rendered as shown in the example.
- If multiple "charges" are present, a heading is added to each table to distinguish them.

### Custom styling
Pass `use-default-style: false` to the invoice function to prevent the default font, paper size, and link styling.

To show a logo, set `doc-info.use-logo: true` and `doc-info.logo-file` in your metadata. If either is missing, no logo is rendered.

## Batch Generation
Use [`scripts/generate_invoices.py`](scripts/generate_invoices.py) to generate one PDF per CSV row.
See [`scripts/example_invoices.csv`](scripts/example_invoices.csv) for a ready-to-run sample.

Required CSV columns:
- `date` in `YYYY-MM-DD` format
- `amount`

Optional CSV columns:
- `description`
- `invoice_id`
- `title`
- `output_name`
- `client_name`
- `client_address`
- `client_email`
- `client_phone`
- `charge_date`
- `quantity`
- `qty`
- `hours`
- `rate`
- `tax`
- `discount`

Example:

```bash
python3 scripts/generate_invoices.py scripts/example_invoices.csv out/
```

The script uses `metadata.local.yaml` as the base invoice configuration by default, so your existing branding, payment details, style, and preparer metadata are reused for every generated invoice.

## Roadmap
Feedback from the community is welcome! No additional features are currently planned other than bugfixes.
