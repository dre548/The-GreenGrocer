/*
  Warnings:

  - The values [PREPARING,EN_ROUTE] on the enum `OrderStatus` will be removed. If these variants are still used in the database, this will fail.
  - You are about to drop the column `delivered_at` on the `Order` table. All the data in the column will be lost.
  - You are about to alter the column `subtotal` on the `Order` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.
  - You are about to alter the column `delivery_fee` on the `Order` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.
  - You are about to alter the column `total` on the `Order` table. The data in that column could be lost. The data in that column will be cast from `DoublePrecision` to `Integer`.
  - You are about to drop the column `current_lat` on the `Rider` table. All the data in the column will be lost.
  - You are about to drop the column `current_lng` on the `Rider` table. All the data in the column will be lost.
  - You are about to drop the column `is_online` on the `Rider` table. All the data in the column will be lost.
  - You are about to drop the column `kyc_status` on the `Rider` table. All the data in the column will be lost.
  - You are about to drop the column `rating` on the `Rider` table. All the data in the column will be lost.
  - The `status` column on the `Transaction` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - You are about to drop the column `lat` on the `Vendor` table. All the data in the column will be lost.
  - You are about to drop the column `lng` on the `Vendor` table. All the data in the column will be lost.
  - The `status` column on the `Vendor` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - You are about to drop the `MenuItem` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Wallet` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `id_back_url` to the `Rider` table without a default value. This is not possible if the table is not empty.
  - Added the required column `id_front_url` to the `Rider` table without a default value. This is not possible if the table is not empty.
  - Added the required column `plate_number` to the `Rider` table without a default value. This is not possible if the table is not empty.
  - Added the required column `party_id` to the `Transaction` table without a default value. This is not possible if the table is not empty.
  - Changed the type of `party` on the `Transaction` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- CreateEnum
CREATE TYPE "ApprovalStatus" AS ENUM ('PENDING', 'ACTIVE', 'REJECTED');

-- CreateEnum
CREATE TYPE "TransactionParty" AS ENUM ('VENDOR', 'RIDER', 'PLATFORM');

-- CreateEnum
CREATE TYPE "TransactionStatus" AS ENUM ('PENDING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "RatingTarget" AS ENUM ('VENDOR', 'RIDER');

-- AlterEnum
BEGIN;
CREATE TYPE "OrderStatus_new" AS ENUM ('PLACED', 'ACCEPTED_BY_VENDOR', 'READY_FOR_PICKUP', 'RIDER_ASSIGNED', 'PICKED_UP', 'DELIVERED', 'CANCELLED');
ALTER TABLE "public"."Order" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "Order" ALTER COLUMN "status" TYPE "OrderStatus_new" USING ("status"::text::"OrderStatus_new");
ALTER TYPE "OrderStatus" RENAME TO "OrderStatus_old";
ALTER TYPE "OrderStatus_new" RENAME TO "OrderStatus";
DROP TYPE "public"."OrderStatus_old";
ALTER TABLE "Order" ALTER COLUMN "status" SET DEFAULT 'PLACED';
COMMIT;

-- AlterEnum
ALTER TYPE "TransactionType" ADD VALUE 'CREDIT';

-- DropForeignKey
ALTER TABLE "MenuItem" DROP CONSTRAINT "MenuItem_vendor_id_fkey";

-- AlterTable
ALTER TABLE "Order" DROP COLUMN "delivered_at",
ALTER COLUMN "subtotal" SET DATA TYPE INTEGER,
ALTER COLUMN "delivery_fee" SET DATA TYPE INTEGER,
ALTER COLUMN "total" SET DATA TYPE INTEGER;

-- AlterTable
ALTER TABLE "Rider" DROP COLUMN "current_lat",
DROP COLUMN "current_lng",
DROP COLUMN "is_online",
DROP COLUMN "kyc_status",
DROP COLUMN "rating",
ADD COLUMN     "id_back_url" TEXT NOT NULL,
ADD COLUMN     "id_front_url" TEXT NOT NULL,
ADD COLUMN     "plate_number" TEXT NOT NULL,
ADD COLUMN     "status" "ApprovalStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN     "wallet_balance" DOUBLE PRECISION NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "Transaction" ADD COLUMN     "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "method" TEXT,
ADD COLUMN     "party_id" TEXT NOT NULL,
DROP COLUMN "party",
ADD COLUMN     "party" "TransactionParty" NOT NULL,
DROP COLUMN "status",
ADD COLUMN     "status" "TransactionStatus" NOT NULL DEFAULT 'PENDING';

-- AlterTable
ALTER TABLE "Vendor" DROP COLUMN "lat",
DROP COLUMN "lng",
ADD COLUMN     "location" TEXT,
ADD COLUMN     "wallet_balance" DOUBLE PRECISION NOT NULL DEFAULT 0,
ALTER COLUMN "commission_rate" DROP NOT NULL,
DROP COLUMN "status",
ADD COLUMN     "status" "ApprovalStatus" NOT NULL DEFAULT 'PENDING';

-- DropTable
DROP TABLE "MenuItem";

-- DropTable
DROP TABLE "Wallet";

-- CreateTable
CREATE TABLE "Product" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "price" INTEGER NOT NULL,
    "emoji" TEXT,
    "unit" TEXT NOT NULL,
    "image_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Product_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Rating" (
    "id" TEXT NOT NULL,
    "order_id" TEXT NOT NULL,
    "target" "RatingTarget" NOT NULL,
    "target_id" TEXT NOT NULL,
    "score" INTEGER NOT NULL,
    "comment" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Rating_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "Transaction" ADD CONSTRAINT "Transaction_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "Order"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Rating" ADD CONSTRAINT "Rating_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
