`catalog.tsv.gz` is made on every CI build by `tool/build_aifa_catalog.dart`
from AIFA's open-data list of medicine packs, and is not kept in git. Without
it the app still builds and works: barcodes then fall back to reading the
text on the box.
