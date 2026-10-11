import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";
import { CustomerRequest } from "./customer-session.guard";
import { normalizeIranPhone } from "./dto/phone.dto";
import { UpdateCustomerProfileDto } from "./dto/update-customer-profile.dto";
import { SaveCustomerAddressDto } from "./dto/save-customer-address.dto";
import { RubikaBotService } from "../integrations/rubika/rubika.service";

@Injectable()
export class CustomerService {
  constructor(private readonly prisma: PrismaService, private readonly rubika: RubikaBotService) {}

  async getProfile(request: CustomerRequest) {
    const customer = await this.prisma.customer.findUniqueOrThrow({
      where: { id: request.customer!.id },
      include: { addresses: { orderBy: [{ isDefault: "desc" }, { updatedAt: "desc" }] } },
    });
    return {
      data: {
        id: customer.id.toString(),
        phone: customer.phone,
        fullName: customer.fullName,
        email: customer.email,
        phoneVerifiedAt: customer.phoneVerifiedAt?.toISOString() ?? null,
        marketingOptIn: customer.marketingOptIn,
        rubikaMarketingOptIn: customer.rubikaMarketingOptIn,
        rubikaLinked: Boolean(customer.rubikaChatId),
        addresses: customer.addresses.map(toPublicAddress),
      },
    };
  }

  async updateProfile(request: CustomerRequest, input: UpdateCustomerProfileDto) {
    const customer = await this.prisma.customer.update({
      where: { id: request.customer!.id },
      data: {
        fullName: input.fullName.trim(),
        email: input.email?.trim() || null,
        ...(input.marketingOptIn === undefined ? {} : {
          marketingOptIn: input.marketingOptIn,
          marketingOptInAt: input.marketingOptIn ? new Date() : null,
        }),
        ...(input.rubikaMarketingOptIn === undefined ? {} : {
          rubikaMarketingOptIn: input.rubikaMarketingOptIn,
          rubikaMarketingOptInAt: input.rubikaMarketingOptIn ? new Date() : null,
        }),
      },
    });
    return { data: {
      id: customer.id.toString(), phone: customer.phone, fullName: customer.fullName, email: customer.email,
      marketingOptIn: customer.marketingOptIn, rubikaMarketingOptIn: customer.rubikaMarketingOptIn,
      rubikaLinked: Boolean(customer.rubikaChatId),
    } };
  }

  async createRubikaLinkCode(request: CustomerRequest) {
    const result = await this.rubika.createLinkCode(request.customer!.id);
    return { data: result };
  }

  async unlinkRubika(request: CustomerRequest) {
    await this.prisma.customer.update({
      where: { id: request.customer!.id },
      data: { rubikaChatId: null, rubikaMarketingOptIn: false, rubikaMarketingOptInAt: null },
    });
    await this.prisma.customerRubikaLinkCode.updateMany({
      where: { customerId: request.customer!.id, usedAt: null }, data: { expiresAt: new Date() },
    });
    return { data: { unlinked: true } };
  }

  async listAddresses(request: CustomerRequest) {
    const addresses = await this.prisma.customerAddress.findMany({
      where: { customerId: request.customer!.id },
      orderBy: [{ isDefault: "desc" }, { updatedAt: "desc" }],
    });
    return { data: addresses.map(toPublicAddress) };
  }

  async saveAddress(request: CustomerRequest, input: SaveCustomerAddressDto) {
    const customerId = request.customer!.id;
    const address = await this.prisma.$transaction(async (tx) => {
      const existingCount = await tx.customerAddress.count({ where: { customerId } });
      const isDefault = input.isDefault === true || existingCount === 0;
      if (isDefault) {
        await tx.customerAddress.updateMany({ where: { customerId }, data: { isDefault: false } });
      }
      return tx.customerAddress.create({ data: addressData(customerId, input, isDefault) });
    });
    return { data: toPublicAddress(address) };
  }

  async updateAddress(request: CustomerRequest, addressIdText: string, input: SaveCustomerAddressDto) {
    const customerId = request.customer!.id;
    const addressId = parseAddressId(addressIdText);
    const current = await this.prisma.customerAddress.findFirst({ where: { id: addressId, customerId } });
    if (!current) throw new NotFoundException({ code: "CUSTOMER_ADDRESS_NOT_FOUND", message: "نشانی پیدا نشد." });
    const isDefault = input.isDefault === true || current.isDefault;
    const address = await this.prisma.$transaction(async (tx) => {
      if (isDefault) {
        await tx.customerAddress.updateMany({ where: { customerId, id: { not: addressId } }, data: { isDefault: false } });
      }
      return tx.customerAddress.update({ where: { id: addressId }, data: addressData(customerId, input, isDefault) });
    });
    return { data: toPublicAddress(address) };
  }

  async setDefaultAddress(request: CustomerRequest, addressIdText: string) {
    const customerId = request.customer!.id;
    const addressId = parseAddressId(addressIdText);
    const address = await this.prisma.$transaction(async (tx) => {
      const count = await tx.customerAddress.updateMany({ where: { id: addressId, customerId }, data: { isDefault: true } });
      if (count.count !== 1) throw new NotFoundException({ code: "CUSTOMER_ADDRESS_NOT_FOUND", message: "نشانی پیدا نشد." });
      await tx.customerAddress.updateMany({ where: { customerId, id: { not: addressId } }, data: { isDefault: false } });
      return tx.customerAddress.findUniqueOrThrow({ where: { id: addressId } });
    });
    return { data: toPublicAddress(address) };
  }

  async deleteAddress(request: CustomerRequest, addressIdText: string) {
    const customerId = request.customer!.id;
    const addressId = parseAddressId(addressIdText);
    const current = await this.prisma.customerAddress.findFirst({ where: { id: addressId, customerId } });
    if (!current) throw new NotFoundException({ code: "CUSTOMER_ADDRESS_NOT_FOUND", message: "نشانی پیدا نشد." });
    await this.prisma.$transaction(async (tx) => {
      await tx.customerAddress.delete({ where: { id: addressId } });
      if (current.isDefault) {
        const next = await tx.customerAddress.findFirst({ where: { customerId }, orderBy: { updatedAt: "desc" } });
        if (next) await tx.customerAddress.update({ where: { id: next.id }, data: { isDefault: true } });
      }
    });
    return { data: { deleted: true } };
  }

  async listOrders(request: CustomerRequest) {
    const orders = await this.prisma.order.findMany({
      where: { customerId: request.customer!.id },
      orderBy: { createdAt: "desc" },
      take: 30,
      select: {
        orderNumber: true,
        status: true,
        paymentStatus: true,
        totalToman: true,
        placedAt: true,
        reservationExpiresAt: true,
        items: { select: { productNameSnapshot: true, colorNameSnapshot: true, sizeLabelSnapshot: true, quantity: true } },
      },
    });
    return {
      data: orders.map((order) => ({
        orderNumber: order.orderNumber,
        status: order.status,
        paymentStatus: order.paymentStatus,
        totalToman: toSafeNumber(order.totalToman),
        placedAt: order.placedAt.toISOString(),
        reservationExpiresAt: order.reservationExpiresAt?.toISOString() ?? null,
        items: order.items.map((item) => ({ name: item.productNameSnapshot, color: item.colorNameSnapshot, size: item.sizeLabelSnapshot, quantity: item.quantity })),
      })),
    };
  }
}

function addressData(customerId: bigint, input: SaveCustomerAddressDto, isDefault: boolean) {
  const street = input.street.trim();
  const alley = input.alley?.trim() || null;
  const plaqueNumber = input.plaqueNumber.trim();
  const unit = input.unit?.trim() || null;
  const deliveryDetails = input.deliveryDetails?.trim() || null;
  const addressLine = [
    street,
    alley ? `کوچه ${alley}` : null,
    `پلاک ${plaqueNumber}`,
    unit ? `واحد ${unit}` : null,
    deliveryDetails,
  ].filter(Boolean).join("، ");
  if (addressLine.length > 500) {
    throw new BadRequestException({ code: "ADDRESS_TOO_LONG", message: "نشانی کامل بیش از اندازه طولانی است." });
  }
  return {
    customerId,
    title: input.title?.trim() || null,
    recipientName: input.recipientName.trim(),
    recipientPhone: normalizeIranPhone(input.recipientPhone),
    province: input.province.trim(),
    city: input.city.trim(),
    street,
    alley,
    plaqueNumber,
    unit,
    deliveryDetails,
    addressLine,
    postalCode: input.postalCode,
    isDefault,
  };
}

function toPublicAddress(address: {
  id: bigint; title: string | null; recipientName: string; recipientPhone: string; province: string; city: string;
  street: string | null; alley: string | null; plaqueNumber: string | null; unit: string | null;
  deliveryDetails: string | null; addressLine: string; postalCode: string; isDefault: boolean;
}) {
  return {
    id: address.id.toString(),
    title: address.title,
    recipientName: address.recipientName,
    recipientPhone: address.recipientPhone,
    province: address.province,
    city: address.city,
    street: address.street,
    alley: address.alley,
    plaqueNumber: address.plaqueNumber,
    unit: address.unit,
    deliveryDetails: address.deliveryDetails,
    addressLine: address.addressLine,
    postalCode: address.postalCode,
    isDefault: address.isDefault,
  };
}

function parseAddressId(value: string): bigint {
  if (!/^\d{1,20}$/.test(value)) throw new BadRequestException({ code: "CUSTOMER_ADDRESS_ID_INVALID", message: "شناسهٔ نشانی معتبر نیست." });
  return BigInt(value);
}

function toSafeNumber(value: bigint): number {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) throw new Error("Order total exceeds JavaScript's safe integer range.");
  return number;
}
