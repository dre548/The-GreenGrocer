-- AlterTable
ALTER TABLE "Product" ADD COLUMN     "in_stock" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "vendor_id" TEXT;

-- AlterTable
ALTER TABLE "Vendor" ADD COLUMN     "is_open" BOOLEAN NOT NULL DEFAULT true;

-- AddForeignKey
ALTER TABLE "Product" ADD CONSTRAINT "Product_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "Vendor"("id") ON DELETE SET NULL ON UPDATE CASCADE;
