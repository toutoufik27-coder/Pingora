CREATE TABLE "auth_tokens" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"purpose" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"used_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "expenses" (
	"id" text PRIMARY KEY NOT NULL,
	"workspace_id" text NOT NULL,
	"property_id" text NOT NULL,
	"date" date NOT NULL,
	"category" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"amount_cents" integer NOT NULL,
	"paid_by" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "imports" (
	"id" text PRIMARY KEY NOT NULL,
	"workspace_id" text NOT NULL,
	"file_name" text NOT NULL,
	"row_count" integer NOT NULL,
	"inserted_count" integer NOT NULL,
	"duplicate_count" integer NOT NULL,
	"skipped_count" integer NOT NULL,
	"error_count" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "listing_mappings" (
	"id" text PRIMARY KEY NOT NULL,
	"workspace_id" text NOT NULL,
	"listing_name" text NOT NULL,
	"property_id" text NOT NULL
);
--> statement-breakpoint
CREATE TABLE "owners" (
	"id" text PRIMARY KEY NOT NULL,
	"workspace_id" text NOT NULL,
	"name" text NOT NULL,
	"email" text,
	"portal_token" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "properties" (
	"id" text PRIMARY KEY NOT NULL,
	"workspace_id" text NOT NULL,
	"owner_id" text,
	"name" text NOT NULL,
	"commission_base" text DEFAULT 'payout' NOT NULL,
	"commission_rate_bps" integer DEFAULT 2000 NOT NULL,
	"exclude_cleaning_fee" boolean DEFAULT true NOT NULL,
	"cleaning_fee_to" text DEFAULT 'owner' NOT NULL,
	"flat_fee_per_reservation_cents" integer DEFAULT 0 NOT NULL,
	"monthly_fee_cents" integer DEFAULT 0 NOT NULL,
	"payout_flow" text DEFAULT 'cohost_collects' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "rate_limit_hits" (
	"id" text PRIMARY KEY NOT NULL,
	"key" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "sessions" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "statement_sends" (
	"id" text PRIMARY KEY NOT NULL,
	"workspace_id" text NOT NULL,
	"owner_id" text NOT NULL,
	"period" text NOT NULL,
	"method" text NOT NULL,
	"sent_to" text,
	"snapshot" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transactions" (
	"id" text PRIMARY KEY NOT NULL,
	"workspace_id" text NOT NULL,
	"import_id" text,
	"property_id" text NOT NULL,
	"fingerprint" text NOT NULL,
	"source" text DEFAULT 'airbnb' NOT NULL,
	"channel" text DEFAULT 'Airbnb' NOT NULL,
	"kind" text NOT NULL,
	"type" text NOT NULL,
	"date" date NOT NULL,
	"booking_date" date,
	"start_date" date,
	"end_date" date,
	"nights" integer,
	"guest" text DEFAULT '' NOT NULL,
	"listing_name" text NOT NULL,
	"confirmation_code" text DEFAULT '' NOT NULL,
	"details" text DEFAULT '' NOT NULL,
	"reference_code" text DEFAULT '' NOT NULL,
	"currency" text DEFAULT 'USD' NOT NULL,
	"amount_cents" integer NOT NULL,
	"service_fee_cents" integer DEFAULT 0 NOT NULL,
	"fast_pay_fee_cents" integer DEFAULT 0 NOT NULL,
	"cleaning_fee_cents" integer DEFAULT 0 NOT NULL,
	"gross_earnings_cents" integer,
	"occupancy_taxes_cents" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" text PRIMARY KEY NOT NULL,
	"workspace_id" text NOT NULL,
	"email" text NOT NULL,
	"name" text NOT NULL,
	"password_hash" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "workspaces" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"attribution_basis" text DEFAULT 'checkin' NOT NULL,
	"default_commission_base" text DEFAULT 'payout' NOT NULL,
	"default_commission_rate_bps" integer DEFAULT 2000 NOT NULL,
	"default_exclude_cleaning_fee" boolean DEFAULT true NOT NULL,
	"default_payout_flow" text DEFAULT 'cohost_collects' NOT NULL,
	"subscription_status" text DEFAULT 'trialing' NOT NULL,
	"trial_ends_at" timestamp with time zone,
	"current_period_ends_at" timestamp with time zone,
	"billing_customer_id" text,
	"billing_subscription_id" text,
	"billing_portal_url" text,
	"billing_updated_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "auth_tokens" ADD CONSTRAINT "auth_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "imports" ADD CONSTRAINT "imports_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "listing_mappings" ADD CONSTRAINT "listing_mappings_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "listing_mappings" ADD CONSTRAINT "listing_mappings_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "owners" ADD CONSTRAINT "owners_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "properties" ADD CONSTRAINT "properties_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "properties" ADD CONSTRAINT "properties_owner_id_owners_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."owners"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "statement_sends" ADD CONSTRAINT "statement_sends_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "statement_sends" ADD CONSTRAINT "statement_sends_owner_id_owners_id_fk" FOREIGN KEY ("owner_id") REFERENCES "public"."owners"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_import_id_imports_id_fk" FOREIGN KEY ("import_id") REFERENCES "public"."imports"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_workspace_id_workspaces_id_fk" FOREIGN KEY ("workspace_id") REFERENCES "public"."workspaces"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "auth_tokens_user_idx" ON "auth_tokens" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "expenses_property_date_idx" ON "expenses" USING btree ("property_id","date");--> statement-breakpoint
CREATE INDEX "imports_workspace_idx" ON "imports" USING btree ("workspace_id");--> statement-breakpoint
CREATE UNIQUE INDEX "listing_mappings_workspace_listing_uq" ON "listing_mappings" USING btree ("workspace_id","listing_name");--> statement-breakpoint
CREATE INDEX "owners_workspace_idx" ON "owners" USING btree ("workspace_id");--> statement-breakpoint
CREATE UNIQUE INDEX "owners_portal_token_uq" ON "owners" USING btree ("portal_token");--> statement-breakpoint
CREATE INDEX "properties_workspace_idx" ON "properties" USING btree ("workspace_id");--> statement-breakpoint
CREATE INDEX "properties_owner_idx" ON "properties" USING btree ("owner_id");--> statement-breakpoint
CREATE INDEX "rate_limit_hits_key_idx" ON "rate_limit_hits" USING btree ("key","created_at");--> statement-breakpoint
CREATE INDEX "sessions_user_idx" ON "sessions" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "statement_sends_owner_period_idx" ON "statement_sends" USING btree ("owner_id","period");--> statement-breakpoint
CREATE UNIQUE INDEX "transactions_workspace_fingerprint_uq" ON "transactions" USING btree ("workspace_id","fingerprint");--> statement-breakpoint
CREATE INDEX "transactions_property_date_idx" ON "transactions" USING btree ("property_id","date");--> statement-breakpoint
CREATE INDEX "transactions_property_start_idx" ON "transactions" USING btree ("property_id","start_date");--> statement-breakpoint
CREATE INDEX "transactions_import_idx" ON "transactions" USING btree ("import_id");--> statement-breakpoint
CREATE UNIQUE INDEX "users_email_uq" ON "users" USING btree ("email");--> statement-breakpoint
CREATE INDEX "users_workspace_idx" ON "users" USING btree ("workspace_id");