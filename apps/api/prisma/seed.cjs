const { PrismaMariaDb } = require("@prisma/adapter-mariadb");
const { PrismaClient } = require("@prisma/client");

const connectionUrl = process.env.DATABASE_URL;
if (!connectionUrl) {
  throw new Error("DATABASE_URL is required to seed the local catalog.");
}

const parsedUrl = new URL(connectionUrl);
const adapter = new PrismaMariaDb({
  host: parsedUrl.hostname,
  port: Number(parsedUrl.port || 3306),
  user: decodeURIComponent(parsedUrl.username),
  password: decodeURIComponent(parsedUrl.password),
  database: decodeURIComponent(parsedUrl.pathname.slice(1)),
});
const prisma = new PrismaClient({ adapter });

const categoryRows = [
  { name: "پوشاک زنانه", slug: "women", sortOrder: 0, children: [
    { name: "ست ورزشی", slug: "sportswear", sortOrder: 1 },
    { name: "لباس راحتی", slug: "loungewear", sortOrder: 2 },
    { name: "مانتو", slug: "coats", sortOrder: 3 },
    { name: "تیشرت و بلوز", slug: "tops", sortOrder: 4 },
    { name: "پیراهن", slug: "dresses", sortOrder: 5 },
  ] },
];

const products = [
  { slug: "lotus-loungewear-set", name: "ست راحتی لوتوس", category: "loungewear", price: 1490000, compareAt: 1890000, image: "/images/paniz-sage.webp", alt: "ست زنانه سبز روشن برای استایل روزمره", colors: [{ name: "سبز نعنایی", hex: "#a9b99f" }, { name: "صورتی", hex: "#d88d9a" }, { name: "کرم", hex: "#d6c2ac" }], sizes: ["S", "M", "L", "XL"] },
  { slug: "avin-cotton-coat", name: "مانتو کتان آوین", category: "coats", price: 2390000, image: "/images/paniz-linen.webp", alt: "استایل زنانه شهری با مانتوی آزاد", colors: [{ name: "شیری", hex: "#dfd3c1" }, { name: "آجری", hex: "#b96f60" }, { name: "ذغالی", hex: "#444448" }], sizes: ["36", "38", "40", "42"] },
  { slug: "mina-cotton-dress", name: "پیراهن نخی مینا", category: "dresses", price: 1280000, compareAt: 1590000, image: "/images/paniz-peach.webp", alt: "پیراهن زنانه با رنگ ملایم و پارچه سبک", colors: [{ name: "گلبهی", hex: "#d59a9c" }, { name: "یاسی", hex: "#a9a2ca" }, { name: "سبز زیتونی", hex: "#78866e" }], sizes: ["S", "M", "L"] },
  { slug: "nova-sports-set", name: "ست ورزشی نوا", category: "sportswear", price: 1790000, image: "/images/paniz-lilac.webp", alt: "پوشاک زنانه راحت برای حرکت و ورزش", colors: [{ name: "صورتی چرک", hex: "#ba7c86" }, { name: "مشکی", hex: "#29292d" }, { name: "یاسی", hex: "#aaa5cc" }], sizes: ["S", "M", "L", "XL"] },
  { slug: "rojan-cotton-blouse", name: "بلوز نخی روژان", category: "tops", price: 790000, image: "/images/paniz-peach.webp", alt: "بلوز زنانه برای استایل مینیمال روزانه", colors: [{ name: "سفید", hex: "#f0ebe3" }, { name: "صورتی", hex: "#d88f9e" }, { name: "آبی روشن", hex: "#91a9bb" }], sizes: ["S", "M", "L"] },
  { slug: "mahtab-loungewear-set", name: "ست راحتی مهتاب", category: "loungewear", price: 1690000, compareAt: 1990000, image: "/images/paniz-sage.webp", alt: "لباس زنانه راحت در رنگ روشن", colors: [{ name: "هلویی", hex: "#d9997d" }, { name: "کرم", hex: "#d8c7af" }, { name: "قهوه‌ای", hex: "#80695f" }], sizes: ["S", "M", "L", "XL"] },
  { slug: "taraneh-linen-coat", name: "مانتو لینن ترانه", category: "coats", price: 2690000, image: "/images/paniz-linen.webp", alt: "استایل خیابانی زنانه در روز آفتابی", colors: [{ name: "کرم", hex: "#d6c4aa" }, { name: "آبی", hex: "#859ab1" }, { name: "مشکی", hex: "#333236" }], sizes: ["36", "38", "40", "42"] },
  { slug: "nika-everyday-tshirt", name: "تیشرت روزمره نیکا", category: "tops", price: 690000, compareAt: 850000, image: "/images/paniz-lilac.webp", alt: "استایل ساده زنانه با رنگ‌های آرام", colors: [{ name: "یاسی", hex: "#a69ec5" }, { name: "شیری", hex: "#e7dfd2" }, { name: "سبز", hex: "#91a184" }], sizes: ["S", "M", "L", "XL"] },
];

function variantRows(product) {
  return product.colors.flatMap((color, colorIndex) => product.sizes.map((size, sizeIndex) => {
    const sku = `${product.slug}-${colorIndex + 1}-${size}`.toUpperCase();
    const values = {
      sku,
      colorName: color.name,
      colorHex: color.hex,
      sizeLabel: size,
      priceToman: BigInt(product.price),
      compareAtPriceToman: product.compareAt ? BigInt(product.compareAt) : null,
      isActive: true,
    };
    return {
      where: { sku },
      create: { ...values, stockQuantity: 5 + ((colorIndex + sizeIndex) % 4) },
      // Re-seeding demo records updates catalog values but never resets stock.
      update: values,
    };
  }));
}

async function main() {
  const categoryIds = new Map();
  for (const root of categoryRows) {
    const parent = await prisma.category.upsert({
      where: { slug: root.slug },
      create: { name: root.name, slug: root.slug, sortOrder: root.sortOrder },
      update: { name: root.name, sortOrder: root.sortOrder, isActive: true },
    });

    for (const child of root.children) {
      const saved = await prisma.category.upsert({
        where: { slug: child.slug },
        create: { name: child.name, slug: child.slug, sortOrder: child.sortOrder, parentId: parent.id },
        update: { name: child.name, sortOrder: child.sortOrder, parentId: parent.id, isActive: true },
      });
      categoryIds.set(child.slug, saved.id);
    }
  }

  for (const product of products) {
    const description = `${product.name}؛ نمونهٔ نمایشی کاتالوگ PanizStyle برای محیط توسعه.`;
    await prisma.product.upsert({
      where: { slug: product.slug },
      create: {
        slug: product.slug,
        name: product.name,
        categoryId: categoryIds.get(product.category),
        shortDescription: description,
        description,
        status: "published",
        publishedAt: new Date(),
        images: { create: [{ imagePath: product.image, altText: product.alt, isPrimary: true }] },
        variants: { create: variantRows(product).map((row) => row.create) },
      },
      update: {
        name: product.name,
        categoryId: categoryIds.get(product.category),
        shortDescription: description,
        description,
        status: "published",
        deletedAt: null,
        images: {
          deleteMany: {},
          create: [{ imagePath: product.image, altText: product.alt, isPrimary: true }],
        },
        variants: { upsert: variantRows(product) },
      },
    });
  }

  console.log(`Seeded ${products.length} development-only catalog products.`);
}

main()
  .catch((error) => {
    console.error("Catalog seed failed.", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
