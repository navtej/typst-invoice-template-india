#let theme-defaults = (
  accent-color: rgb("#0f4c5c"),
  accent-soft-color: rgb("#e8f3f4"),
  surface-color: rgb("#f8fafc"),
  surface-strong-color: rgb("#eef4f8"),
  border-color: rgb("#d7e1e8"),
  muted-color: rgb("#5b6b79"),
  title-color: rgb("#102a43"),
  total-fill-color: rgb("#12344d"),
  total-text-color: white,
)

#let default-currency = state("currency-state", "$")
#let default-hundreds-separator = state("separator-state", ",")
#let default-decimal = state("decimal-state", ".")
#let default-accent-color = state("accent-color-state", theme-defaults.at("accent-color"))
#let default-accent-soft-color = state("accent-soft-color-state", theme-defaults.at("accent-soft-color"))
#let default-surface-color = state("surface-color-state", theme-defaults.at("surface-color"))
#let default-surface-strong-color = state("surface-strong-color-state", theme-defaults.at("surface-strong-color"))
#let default-border-color = state("border-color-state", theme-defaults.at("border-color"))
#let default-muted-color = state("muted-color-state", theme-defaults.at("muted-color"))
#let default-title-color = state("title-color-state", theme-defaults.at("title-color"))
#let default-total-fill-color = state("total-fill-color-state", theme-defaults.at("total-fill-color"))
#let default-total-text-color = state("total-text-color-state", theme-defaults.at("total-text-color"))

#let normalize-date(date) = {
  if type(date) == str {
    let pieces = date.split("-").map(int)
    datetime(year: pieces.at(0), month: pieces.at(1), day: pieces.at(2))
  } else if date == none {
    datetime.today()
  } else {
    date
  }
}

#let date-to-str(date, format: "[day padding:none] [month repr:long] [year]") = {
  let to-format = normalize-date(date)

  if type(to-format) == datetime {
    to-format.display(format)
  } else {
    to-format
  }
}

#let check-dict-keys(dict, ..keys) = {
  assert(type(dict) == dictionary, message: "dict must be a dictionary")
  for key in keys.pos() {
    assert(key in dict, message: "dict must contain key: " + repr(key))
  }
}

#let resolve-style-value(value) = {
  if type(value) == str {
    eval(value)
  } else {
    value
  }
}

#let style-value(style, key, default) = resolve-style-value(style.at(key, default: default))

#let format-doc-id(id-info, date) = {
  if type(id-info) != dictionary {
    return [#id-info]
  }

  check-dict-keys(id-info, "prefix", "separator", "format", "id")
  assert(id-info.prefix.len() >= 3, message: "doc-info.id.prefix must be at least 3 characters")
  assert(id-info.separator.len() == 1, message: "doc-info.id.separator must be exactly 1 character")

  let doc-date = normalize-date(date)
  assert(type(doc-date) == datetime, message: "doc-info.date must be a date or YYYY-MM-DD string")

  let parts = ()
  for piece in id-info.format {
    if piece == "prefix" {
      parts.push(id-info.prefix)
    } else if piece == "year" {
      parts.push(doc-date.display("[year]"))
    } else if piece == "month" {
      parts.push(doc-date.display("[month padding:zero]"))
    } else if piece == "month-name" {
      parts.push(doc-date.display("[month repr:long]"))
    } else if piece == "id" {
      parts.push(str(id-info.id))
    } else {
      panic("Unsupported doc-info.id format token: " + repr(piece))
    }
  }

  [
    #for (index, part) in parts.enumerate() {
      part
      if index < parts.len() - 1 {
        id-info.separator
      }
    }
  ]
}

#let format-tax-details(tax-details) = {
  if tax-details == none {
    return []
  }

  let lines = ()
  for key in ("GST", "LUT", "PAN") {
    if key in tax-details {
      lines.push([*#key:* #tax-details.at(key)])
    }
  }

  if lines.len() == 0 {
    []
  } else {
    [
      #v(0.75em)
      #for (index, line) in lines.enumerate() {
        line
        if index < lines.len() - 1 {
          linebreak()
        }
      }
    ]
  }
}

#let format-company-info(
  info,
  title: none,
  heading-key: "company-name",
  use-attn: true,
  extra-details: none,
) = {
  check-dict-keys(info, heading-key, "address", "name", "email", "phone")
  context block(
    inset: 0.95em,
    radius: 12pt,
    fill: default-surface-color.get(),
    stroke: (paint: default-border-color.get(), thickness: 0.8pt),
  )[
    #set text(size: 0.9em)
    #text(weight: "bold", size: 0.76em, fill: default-accent-color.get())[#title]
    #v(0.45em)
    #text(weight: "semibold", size: 1.18em, fill: default-title-color.get())[#info.at(heading-key)]
    #v(0.2em)
    #set text(fill: default-muted-color.get())
    #info.address

    #v(0.55em)
    #if use-attn [Attn: #info.name#linebreak()]
    #link("mailto:" + info.email)\
    #info.phone
    #extra-details
  ]
}

#let format-doc-info(info) = {
  check-dict-keys(info, "title", "id", "date")

  context block(
    inset: 1.05em,
    radius: 16pt,
    fill: default-surface-strong-color.get(),
    stroke: (paint: default-border-color.get(), thickness: 0.8pt),
  )[
    #v(0.35em)
    #text(size: 2.35em, weight: "extrabold", fill: default-title-color.get())[#info.title]
    #v(0.4em)
    #grid(
      columns: (auto, 1fr),
      column-gutter: 0.6em,
      row-gutter: 0.35em,
    )[
      #text(weight: "bold", fill: default-title-color.get())[ID]
    ][
      #text(fill: default-muted-color.get())[#format-doc-id(info.id, info.date)]
    ][
      #text(weight: "bold", fill: default-title-color.get())[Date]
    ][
      #text(fill: default-muted-color.get())[#date-to-str(info.date)]
    ]
    #if "valid-through" in info [
      #v(0.35em)
      #grid(columns: (auto, 1fr), column-gutter: 0.6em)[
        #text(weight: "bold", fill: default-title-color.get())[Valid Through]
      ][
        #text(fill: default-muted-color.get())[#date-to-str(info.valid-through)]
      ]
    ]
  ]
}

#let format-frontmatter(preparer-info, client-info, doc-info) = context [
  #grid(columns: (1.4fr, 0.8fr), column-gutter: 1.2em, row-gutter: 1em)[
    #format-doc-info(doc-info)
  ][
    #set align(top + right)
    #if doc-info.at("logo", default: none) != none [
      #block(
        inset: 0.8em,
        radius: 14pt,
        fill: white,
        stroke: (paint: default-border-color.get(), thickness: 0.8pt),
      )[
        #doc-info.at("logo")
      ]
    ]
  ]
  #v(0.85em)
  #line(length: 100%, stroke: (paint: default-border-color.get(), thickness: 1pt))
  #v(1em)

  #grid(columns: 2, column-gutter: 1fr)[
    #format-company-info(
      client-info,
      title: [TO],
      heading-key: "name",
      use-attn: false,
    )
  ][
    #format-company-info(
      preparer-info,
      title: [FROM],
      heading-key: "name",
      use-attn: false,
      extra-details: format-tax-details(preparer-info.at("tax-details", default: none)),
    )
  ]

  #v(0.8em)
]

#let format-account-details(account-details) = {
  if type(account-details) == dictionary {
    let cells = ()
    for (key, value) in account-details.pairs() {
      cells.push(text(weight: "bold", fill: default-title-color.get())[#key])
      cells.push(text(fill: default-muted-color.get())[#value])
    }
    return [
      #grid(
        columns: (auto, 1fr),
        column-gutter: 0.7em,
        row-gutter: 0.35em,
        ..cells,
      )
    ]
  }

  account-details
}

#let format-payment-info(payment-info) = {
  check-dict-keys(payment-info, "payment-window", "account-details")
  context block(
    breakable: false,
    inset: 0.95em,
    radius: 12pt,
    fill: default-surface-color.get(),
    stroke: (paint: default-border-color.get(), thickness: 0.8pt),
  )[
    #text(weight: "bold", size: 0.76em, fill: default-accent-color.get())[PAYMENT DETAILS]
    #v(0.4em)
    #text(weight: "semibold", fill: default-title-color.get())[Due within #payment-info.payment-window of receipt.]
    #v(0.55em)
    #set text(fill: default-muted-color.get())
    #format-account-details(payment-info.account-details)
  ]
}

#let price-formatter(number, currency: auto, separator: auto, decimal: auto, digits: 2) ={
  // Adds commas after each 3 digits to make
  // pricing more readable
  context {
    let currency = if currency == auto { default-currency.get() } else { currency }
    let separator = if separator == auto { default-hundreds-separator.get() } else { separator }
    let decimal = if decimal == auto { default-decimal.get() } else { decimal }

    let integer-portion = str(calc.abs(calc.trunc(number)))
    let num-length = integer-portion.len()
    let num-with-commas = ""

    for ii in range(num-length) {
      if calc.rem(ii, 3) == 0 and ii > 0 {
        num-with-commas = separator + num-with-commas
      }
      num-with-commas = integer-portion.at(-ii - 1) + num-with-commas
    }
    // Another "round" is needed to offset float imprecision
    let fraction = calc.round(calc.fract(number), digits: digits + 1)
    let fraction-int = calc.round(fraction * calc.pow(10, digits))
    if fraction-int == 0 {
      fraction-int = ""
    } else {
      fraction-int = decimal + str(fraction-int)
    }
    let formatted = currency + num-with-commas + fraction-int
    if number < 0 {
      formatted = "(" + formatted + ")"
    }
    formatted
  }
}

#let c(body, ..args) = context table.cell(
  inset: (x: 1.1em, y: 0.85em),
  fill: default-accent-soft-color.get(),
  ..args,
  text(weight: "bold", fill: default-accent-color.get(), body),
)

#let total-bill(amount) = {
  context grid(columns: (auto, auto))[
  ][
    #block(
      inset: 0.25em,
      radius: 14pt,
      fill: default-total-fill-color.get(),
    )[
      #table(
        columns: (auto, auto),
        align: (auto, right),
        stroke: none,
        inset: (x: 1em, y: 0.65em),
        table.hline(y: 0, stroke: (paint: white.transparentize(65%), thickness: 0.7pt)),
        table.hline(y: 1, stroke: (paint: white.transparentize(65%), thickness: 0.7pt)),
        table.cell(text(weight: "bold", fill: default-total-text-color.get(), [TOTAL])),
        table.cell(text(weight: "bold", fill: default-total-text-color.get(), [#price-formatter(amount)])),
      )
    ]
  ]
}

#let _format-charge-value(value, info, row-total, row-number) = {
  // TODO: Account for other helpful types like datetime
  if value == none {
    return (value, row-total, false)
  }
  let typ = info.at("type")
  let did-multiply = false
  if typ not in ("string", "index") {
    let multiplier = value
    if info.at("negative", default: false) {
      multiplier *= -1
    }
    if typ == "percent" {
      multiplier = 1 + multiplier/100
    }
    if row-total == none {
      row-total = if typ == "currency" { value } else { 1 }
    } else {
      row-total *= multiplier
    }
    if typ != "currency" or row-total != value {
      did-multiply = true
    }
  }
  let out-value = value
  if typ == "currency" {
    out-value = price-formatter(value)
  } else if typ == "percent" {
    out-value = value
  } else if typ == "string" {
    out-value = eval(value, mode: "markup")
  } else if typ == "index" and value == "" {
    out-value = row-number
  }
  if "suffix" in info {
    out-value = [#out-value#info.at("suffix")]
  } else {
    out-value = [#out-value]
  }
  (out-value, row-total, did-multiply)
}

#let _format-charge-columns(charge-info) = {
  let get-eval(dict, key, default) = {
    let value = dict.at(key, default: default)
    if type(value) == str {
      eval(value)
    }
    else {
      value
    }
  }

  let (names, aligns, widths) = ((), (), ())
  for (key, info) in charge-info.pairs() {
    key = upper(key.at(0)) + key.slice(1)
    names.push(c(key))
    let default-align = if info.at("type") == "string" { left } else { right }
    aligns.push(get-eval(info, "align", default-align))
    widths.push(get-eval(info, "width", auto))
  }
  // Keys correspond to table specs other than "names" which is positional
  (names: names, align: aligns, columns: widths)
}

#let bill-table(..items, charge-info: auto) = {
  if charge-info == auto {
    charge-info = (:)
  }
  if items.pos().len() == 0 {
    return (table: none, amount: 0)
  }
  let out = ()
  let total-amount = 0
  let columns = ()
  // A separate "Total" column is only needed if there are >1 multipliers
  let has-multiplier = false
  let found-infos = (:)

  // Initial scan finds all possible fields, and whether a "total"
  // field is needed
  for item in items.pos() {
    let mult-count = 0
    for (key, value) in item.pairs() {
      if key not in charge-info {
        let fallback = (type: type(value))
        charge-info.insert(key, fallback)
      }
      found-infos.insert(key, charge-info.at(key))
      let (_, _, did-multiply) = _format-charge-value(value, charge-info.at(key), 0, 0)
      if did-multiply {
        mult-count += 1
      }
      has-multiplier = has-multiplier or mult-count > 1
    }
  }

  // Now that all needed keys are guaranteed to exist, we can start to format output values
  for (ii, item) in items.pos().enumerate() {
    let row-number = ii + 1
    let row-total = none
    for (key, info) in found-infos.pairs() {
      let default-value = info.at("default", default: none)
      let value = item.at(key, default: default-value)
      let (display-value, new-row-total, _) = _format-charge-value(
        value, info, row-total, row-number
      )

      out.push(display-value)
      row-total = new-row-total
    }
    if row-total == none {
      row-total = 0
    }
    if has-multiplier {
      out.push(price-formatter(row-total))
    }
    total-amount += row-total
  }
  if has-multiplier {
    found-infos.insert("total", (type: "currency"))
  }
  let col-spec = _format-charge-columns(found-infos)
  let names = col-spec.remove("names")
  let tbl = context block(
    radius: 14pt,
    stroke: (paint: default-border-color.get(), thickness: 0.8pt),
    clip: true,
  )[
    #table(
      columns: col-spec.columns,
      align: col-spec.align,
      stroke: none,
      inset: (x: 1em, y: 0.7em),
      table.hline(y: 0, stroke: (paint: default-border-color.get(), thickness: 0.8pt)),
      table.hline(y: 1, stroke: (paint: default-border-color.get(), thickness: 0.8pt)),
      ..names,
      ..out,
    )
  ]
  (table: tbl, amount: total-amount)
}


#let invoice(
  body,
  preparer-info: none,
  client-info: none,
  payment-info: none,
  doc-info: none,
  style: none,
  apply-default-style: true,
) = {
  let style = if style == none { (:) } else { style }
  let font-face = style.at("font-face", default: "Arial")
  let font-size = style.at("font-size", default: 11pt)
  let font-color = style.at("font-color", default: black)
  let hyphenate = style.at("hyphenate", default: false)
  let link-color = style.at("link-color", default: blue.darken(20%))
  let paper = style.at("paper", default: "us-letter")
  let page-margin = style.at("page-margin", default: 0.8in)
  let accent-color = style-value(style, "accent-color", theme-defaults.at("accent-color"))
  let accent-soft-color = style-value(style, "accent-soft-color", theme-defaults.at("accent-soft-color"))
  let surface-color = style-value(style, "surface-color", theme-defaults.at("surface-color"))
  let surface-strong-color = style-value(style, "surface-strong-color", theme-defaults.at("surface-strong-color"))
  let border-color = style-value(style, "border-color", theme-defaults.at("border-color"))
  let muted-color = style-value(style, "muted-color", theme-defaults.at("muted-color"))
  let title-color = style-value(style, "title-color", theme-defaults.at("title-color"))
  let total-fill-color = style-value(style, "total-fill-color", theme-defaults.at("total-fill-color"))
  let total-text-color = style-value(style, "total-text-color", theme-defaults.at("total-text-color"))

  default-accent-color.update(accent-color)
  default-accent-soft-color.update(accent-soft-color)
  default-surface-color.update(surface-color)
  default-surface-strong-color.update(surface-strong-color)
  default-border-color.update(border-color)
  default-muted-color.update(muted-color)
  default-title-color.update(title-color)
  default-total-fill-color.update(total-fill-color)
  default-total-text-color.update(total-text-color)

  set text(
    font: font-face,
    size: resolve-style-value(font-size),
    fill: resolve-style-value(font-color),
    hyphenate: hyphenate,
  ) if apply-default-style
  set page(
    paper: paper,
    margin: resolve-style-value(page-margin),
    number-align: top + right,
  ) if apply-default-style

  // conditional "set" rules are tricky due to scoping
  show link: content => {
    if apply-default-style {
      set text(fill: resolve-style-value(link-color))
      underline(content)
    } else {
      content
    }
  }

  let frontmatter = format-frontmatter(preparer-info, client-info, doc-info)


  frontmatter

  body
  if payment-info != none {
    format-payment-info(payment-info)
  }
}

#let create-bill-tables(headings-and-charges, charge-info: auto, price-locale: (:)) = {
  if "currency" in price-locale {
    default-currency.update(price-locale.at("currency"))
  }
  if "separator" in price-locale {
    default-hundreds-separator.update(price-locale.at("separator"))
  }
  if "decimal" in price-locale {
    default-decimal.update(price-locale.at("decimal"))
  }

  let needs-heading = headings-and-charges.len() > 1
  let running-total = 0

  for (key, charge-list) in headings-and-charges.pairs() {
    if needs-heading {
      context block(
        inset: (x: 0.9em, y: 0.45em),
        radius: 999pt,
        fill: default-accent-soft-color.get(),
      )[
        #text(weight: "bold", fill: default-accent-color.get())[#key]
      ]
      v(0.55em)
    }
    let bill = bill-table(..charge-list, charge-info: charge-info)
    bill.table
    running-total += bill.amount
    v(1em)
  }

  v(0.7em)
  set align(right) if not needs-heading
  total-bill(running-total)
}

#let remove-or-default(dict, key, default) = {
  // Self assignment allows mutability
  let dict = dict
  if key in dict {
    let value = dict.remove(key)
    (dict, value)
  } else {
    (dict, default)
  }
}

#let invoice-from-metadata(metadata-dict, pre-table-body: [], ..extra-invoice-args) = {
  let meta = metadata-dict
  let charges = (:)
  for key in meta.keys() {
    if lower(key).ends-with("charges") {
      let opts = meta.remove(key)
      charges.insert(key, opts)
    }
  }


  let (meta, info) = remove-or-default(meta, "charge-info", auto)
  let (meta, price-locale) = remove-or-default(meta, "locale", ())

  show: invoice.with(..meta, ..extra-invoice-args)

  pre-table-body

  create-bill-tables(charges, charge-info: info, price-locale: price-locale)
}
