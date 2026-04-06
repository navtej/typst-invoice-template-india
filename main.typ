#import "template.typ": invoice-from-metadata


#let metadata-path = "metadata.local.yaml"
#let meta = yaml(metadata-path)
#if meta.doc-info.at("use-logo", default: false) and "logo-file" in meta.doc-info {
  meta.doc-info.insert("logo", image(meta.doc-info.at("logo-file"), height: 5em))
}
#invoice-from-metadata(meta, pre-table-body: [], apply-default-style: true)
