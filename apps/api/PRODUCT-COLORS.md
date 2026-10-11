# Product color values

The admin app submits a canonical Persian color name and its six-digit HEX value
for every new variant. The API stores the HEX alongside the variant. Public
catalog responses resolve legacy rows with a missing HEX from their color name,
so product cards and product details show a shade that matches the label.

After building the API, run `node scripts/test-product-colors.cjs` to verify
canonical names, common Persian spelling aliases, explicit HEX values and the
neutral fallback for unknown legacy names.
