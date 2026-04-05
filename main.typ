#import "template.typ": invoice-from-metadata


#let metadata-path = "metadata.local.yaml"
#let meta = yaml(metadata-path)
#meta.doc-info.insert("logo", image("logo.svg", height: 5em))
#invoice-from-metadata(meta, pre-table-body: [], apply-default-style: true)
