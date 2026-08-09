-- CreateEnum
CREATE TYPE "PaymentMethodType" AS ENUM ('SEND_MONEY', 'PAYBILL', 'BUY_GOODS');

-- AlterEnum
ALTER TYPE "SupportTicketStatus" ADD VALUE 'RESOLVED';

-- CreateTable
CREATE TABLE "PaymentSettings" (
    "id" TEXT NOT NULL,
    "active_method" "PaymentMethodType" NOT NULL DEFAULT 'SEND_MONEY',
    "send_money_number" TEXT,
    "paybill_number" TEXT,
    "paybill_account" TEXT,
    "buy_goods_till" TEXT,
    "note_enabled" BOOLEAN NOT NULL DEFAULT false,
    "note_text" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PaymentSettings_pkey" PRIMARY KEY ("id")
);
