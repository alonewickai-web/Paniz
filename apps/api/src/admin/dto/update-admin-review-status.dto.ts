import { IsIn } from "class-validator";

export class UpdateAdminReviewStatusDto {
  @IsIn(["pending", "approved", "rejected"])
  status!: "pending" | "approved" | "rejected";
}
