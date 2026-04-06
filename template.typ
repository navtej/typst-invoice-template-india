#let default-currency = state("currency-state", "$")
#let default-hundreds-separator = state("separator-state", ",")
#let default-decimal = state("decimal-state", ".")

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
) = [
  #check-dict-keys(info, heading-key, "address", "name", "email", "phone")
  #title\
  #info.at(heading-key)\
  #info.address

  #if use-attn [Attn: #info.name#linebreak()]
  #link("mailto:" + info.email)\
  #info.phone
  #extra-details
]

#let format-doc-info(info) = [
  #check-dict-keys(info, "title", "id", "date")

  #text(size: 2.75em, weight: "extrabold")[#info.title]
  #v(-2em)
  ID: #format-doc-id(info.id, info.date)\
  Date: #date-to-str(info.date)
  #if "valid-through" in info [
    #linebreak()
    Valid through #date-to-str(info.valid-through)
  ]
]

#let format-frontmatter(preparer-info, client-info, doc-info) = [
  #grid(columns: 2, column-gutter: 1fr)[
    #format-doc-info(doc-info)
  ][
    #set align(bottom)
    #doc-info.at("logo", default: none)
  ]
  #line(length: 100%)
  #v(1em)


  #grid(columns: 2, column-gutter: 1fr)[
    #format-company-info(
      client-info,
      title: [*TO:*],
      heading-key: "name",
      use-attn: false,
    )
  ][
    #format-company-info(
      preparer-info,
      title: [*FROM:*],
      heading-key: "name",
      use-attn: false,
      extra-details: format-tax-details(preparer-info.at("tax-details", default: none)),
    )
  ]

  #v(1em)
]

#let format-payment-info(payment-info) = {
  check-dict-keys(payment-info, "payment-window", "account-details")
  [
    #v(1em)
    *Due within #payment-info.payment-window days of receipt.*

    #payment-info.account-details
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

#let c(body, ..args) = table.cell(inset: 1.25em, ..args, text(weight: "bold", body))

#let total-bill(amount) = {
  grid(columns: (auto, auto))[
  ][
    #table(
      columns: (auto, auto),
      align: (auto, right),
      stroke: none,
      c[TOTAL],
      c[#price-formatter(amount)],
    )
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
  let tbl = table(
    columns: col-spec.columns,
    align: col-spec.align,
    stroke: none,
    inset: 1em,
    ..names,
    ..out,
  )
  (table: tbl, amount: total-amount)
}


#let invoice(
  body,
  preparer-info: none,
  client-info: none,
  payment-info: none,
  doc-info: none,
  apply-default-style: true,
) = {
  set text(font: "Arial", hyphenate: false) if apply-default-style
  set page(paper: "us-letter", margin: 0.8in, number-align: top + right) if apply-default-style

  // conditional "set" rules are tricky due to scoping
  show link: content => {
    if apply-default-style {
      set text(fill: blue.darken(20%))
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
      [= #key]
    }
    let bill = bill-table(..charge-list, charge-info: charge-info)
    bill.table
    running-total += bill.amount

  }

  h(1fr)
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
