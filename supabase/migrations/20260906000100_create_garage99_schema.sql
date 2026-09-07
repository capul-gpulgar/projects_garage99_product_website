begin;

-- Garage99 business schema. The existing public.connection_check table is technical
-- and intentionally remains outside this domain model.
create schema if not exists app;
create schema if not exists api;

create table app.schema_migrations (
    version text primary key,
    applied_at timestamptz not null default now()
);

revoke all on schema app from public, anon, authenticated;
grant usage on schema app to service_role;
revoke all on schema api from public;
grant usage on schema api to anon, authenticated, service_role;
alter default privileges in schema app revoke all on tables from public, anon, authenticated;
alter default privileges in schema app revoke all on sequences from public, anon, authenticated;
alter default privileges in schema api revoke all on tables from public, anon, authenticated;

create table app.categories (
    id uuid primary key default gen_random_uuid(),
    parent_category_id uuid references app.categories(id) on delete restrict,
    name text not null check (btrim(name) <> ''),
    slug text not null unique check (slug = lower(slug) and btrim(slug) <> ''),
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table app.product_brands (
    id uuid primary key default gen_random_uuid(),
    name text not null check (btrim(name) <> ''),
    slug text not null unique check (slug = lower(slug) and btrim(slug) <> ''),
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table app.products (
    id uuid primary key default gen_random_uuid(),
    category_id uuid not null references app.categories(id) on delete restrict,
    brand_id uuid references app.product_brands(id) on delete restrict,
    name text not null check (btrim(name) <> ''),
    slug text not null unique check (slug = lower(slug) and btrim(slug) <> ''),
    description text,
    status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
    attributes jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table app.product_variants (
    id uuid primary key default gen_random_uuid(),
    product_id uuid not null references app.products(id) on delete restrict,
    sku text not null unique check (btrim(sku) <> ''),
    name text not null check (btrim(name) <> ''),
    barcode text,
    cost_amount numeric(12,2) check (cost_amount is null or cost_amount >= 0),
    currency_code char(3) not null default 'CLP' check (currency_code = upper(currency_code)),
    weight_grams integer check (weight_grams is null or weight_grams >= 0),
    active boolean not null default true,
    attributes jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index product_variants_barcode_key
    on app.product_variants (barcode) where barcode is not null;
create index products_category_id_idx on app.products(category_id);
create index products_brand_id_idx on app.products(brand_id);
create index products_published_idx on app.products(id) where status = 'published';
create index product_variants_product_id_idx on app.product_variants(product_id);

create table app.product_images (
    id uuid primary key default gen_random_uuid(),
    product_id uuid references app.products(id) on delete restrict,
    variant_id uuid references app.product_variants(id) on delete restrict,
    storage_path text not null check (btrim(storage_path) <> ''),
    alt_text text,
    sort_order integer not null default 0 check (sort_order >= 0),
    is_primary boolean not null default false,
    created_at timestamptz not null default now(),
    constraint product_images_parent_check check (product_id is not null or variant_id is not null)
);
create unique index product_images_storage_path_key on app.product_images(storage_path);
create unique index product_images_product_primary_key on app.product_images(product_id)
    where product_id is not null and is_primary;
create unique index product_images_variant_primary_key on app.product_images(variant_id)
    where variant_id is not null and is_primary;
create index product_images_product_idx on app.product_images(product_id, sort_order);

create table app.motorcycle_makes (
    id uuid primary key default gen_random_uuid(),
    name text not null check (btrim(name) <> ''),
    slug text not null unique check (slug = lower(slug) and btrim(slug) <> ''),
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table app.motorcycle_models (
    id uuid primary key default gen_random_uuid(),
    make_id uuid not null references app.motorcycle_makes(id) on delete restrict,
    name text not null check (btrim(name) <> ''),
    slug text not null check (slug = lower(slug) and btrim(slug) <> ''),
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (make_id, slug)
);
create index motorcycle_models_make_id_idx on app.motorcycle_models(make_id);

create table app.motorcycle_versions (
    id uuid primary key default gen_random_uuid(),
    model_id uuid not null references app.motorcycle_models(id) on delete restrict,
    name text not null check (btrim(name) <> ''),
    engine_code text,
    displacement_cc integer check (displacement_cc is null or displacement_cc > 0),
    year_from smallint check (year_from is null or year_from between 1900 and 2100),
    year_to smallint check (year_to is null or year_to between 1900 and 2100),
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint motorcycle_versions_year_range_check check (
        year_from is null or year_to is null or year_to >= year_from
    )
);
create index motorcycle_versions_model_year_idx
    on app.motorcycle_versions(model_id, year_from, year_to);

create table app.product_fitments (
    id uuid primary key default gen_random_uuid(),
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    motorcycle_version_id uuid not null references app.motorcycle_versions(id) on delete restrict,
    year_from smallint check (year_from is null or year_from between 1900 and 2100),
    year_to smallint check (year_to is null or year_to between 1900 and 2100),
    notes text,
    source_type text not null default 'unknown'
        check (source_type in ('manufacturer', 'supplier', 'verified_manual', 'unknown')),
    source_reference text,
    verified_at timestamptz,
    created_at timestamptz not null default now(),
    constraint product_fitments_year_range_check check (
        year_from is null or year_to is null or year_to >= year_from
    ),
    unique (variant_id, motorcycle_version_id, year_from, year_to)
);
create index product_fitments_motorcycle_idx
    on app.product_fitments(motorcycle_version_id, year_from, year_to);
create index product_fitments_variant_idx on app.product_fitments(variant_id);

create table app.part_references (
    id uuid primary key default gen_random_uuid(),
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    reference_type text not null check (reference_type in ('oem', 'manufacturer', 'equivalent', 'supplier')),
    reference_brand text,
    reference_code text not null check (btrim(reference_code) <> ''),
    notes text,
    created_at timestamptz not null default now(),
    unique (reference_type, reference_brand, reference_code)
);
create index part_references_code_idx on app.part_references(lower(reference_code));
create index part_references_variant_idx on app.part_references(variant_id);

create table app.suppliers (
    id uuid primary key default gen_random_uuid(),
    legal_name text not null check (btrim(legal_name) <> ''),
    display_name text,
    tax_id text,
    email text,
    phone text,
    active boolean not null default true,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create unique index suppliers_tax_id_key on app.suppliers(tax_id) where tax_id is not null;

create table app.supplier_products (
    id uuid primary key default gen_random_uuid(),
    supplier_id uuid not null references app.suppliers(id) on delete restrict,
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    supplier_sku text not null check (btrim(supplier_sku) <> ''),
    unit_cost_amount numeric(12,2) not null check (unit_cost_amount >= 0),
    currency_code char(3) not null default 'CLP' check (currency_code = upper(currency_code)),
    lead_time_days integer check (lead_time_days is null or lead_time_days >= 0),
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (supplier_id, variant_id),
    unique (supplier_id, supplier_sku)
);
create index supplier_products_variant_idx on app.supplier_products(variant_id);

create table app.purchase_orders (
    id uuid primary key default gen_random_uuid(),
    supplier_id uuid not null references app.suppliers(id) on delete restrict,
    order_number text not null unique,
    status text not null default 'draft'
        check (status in ('draft', 'ordered', 'partially_received', 'received', 'cancelled')),
    ordered_at timestamptz,
    expected_at timestamptz,
    currency_code char(3) not null default 'CLP' check (currency_code = upper(currency_code)),
    subtotal_amount numeric(12,2) not null default 0 check (subtotal_amount >= 0),
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index purchase_orders_supplier_status_idx on app.purchase_orders(supplier_id, status);

create table app.purchase_order_items (
    id uuid primary key default gen_random_uuid(),
    purchase_order_id uuid not null references app.purchase_orders(id) on delete restrict,
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    quantity_ordered integer not null check (quantity_ordered > 0),
    unit_cost_amount numeric(12,2) not null check (unit_cost_amount >= 0),
    quantity_received integer not null default 0 check (quantity_received >= 0),
    created_at timestamptz not null default now(),
    constraint purchase_order_items_received_check check (quantity_received <= quantity_ordered),
    unique (purchase_order_id, variant_id)
);
create index purchase_order_items_variant_idx on app.purchase_order_items(variant_id);

create table app.goods_receipts (
    id uuid primary key default gen_random_uuid(),
    purchase_order_id uuid not null references app.purchase_orders(id) on delete restrict,
    receipt_number text not null unique,
    status text not null default 'draft' check (status in ('draft', 'posted', 'cancelled')),
    received_at timestamptz,
    received_by uuid references auth.users(id) on delete set null,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index goods_receipts_purchase_order_idx on app.goods_receipts(purchase_order_id, status);

create table app.goods_receipt_items (
    id uuid primary key default gen_random_uuid(),
    goods_receipt_id uuid not null references app.goods_receipts(id) on delete restrict,
    purchase_order_item_id uuid not null references app.purchase_order_items(id) on delete restrict,
    quantity_accepted integer not null default 0 check (quantity_accepted >= 0),
    quantity_rejected integer not null default 0 check (quantity_rejected >= 0),
    rejection_reason text,
    created_at timestamptz not null default now(),
    unique (goods_receipt_id, purchase_order_item_id)
);

create table app.customers (
    id uuid primary key default gen_random_uuid(),
    auth_user_id uuid references auth.users(id) on delete set null,
    full_name text not null check (btrim(full_name) <> ''),
    email text,
    phone text,
    tax_id text,
    default_address jsonb,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create unique index customers_auth_user_id_key on app.customers(auth_user_id) where auth_user_id is not null;
create unique index customers_email_key on app.customers(lower(email)) where email is not null;

create table app.sales_channels (
    id uuid primary key default gen_random_uuid(),
    code text not null unique check (code in ('web', 'pos', 'mercadolibre')),
    name text not null,
    active boolean not null default true,
    safety_stock_default integer not null default 1 check (safety_stock_default >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table app.variant_prices (
    id uuid primary key default gen_random_uuid(),
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    channel_id uuid not null references app.sales_channels(id) on delete restrict,
    currency_code char(3) not null default 'CLP' check (currency_code = upper(currency_code)),
    unit_price_amount numeric(12,2) not null check (unit_price_amount >= 0),
    valid_from timestamptz not null default now(),
    valid_to timestamptz,
    active boolean not null default true,
    created_at timestamptz not null default now(),
    constraint variant_prices_validity_check check (valid_to is null or valid_to > valid_from)
);
create index variant_prices_lookup_idx
    on app.variant_prices(variant_id, channel_id, valid_from desc)
    where active;

create table app.orders (
    id uuid primary key default gen_random_uuid(),
    order_number text not null unique default ('G99-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
    customer_id uuid references app.customers(id) on delete set null,
    channel_id uuid not null references app.sales_channels(id) on delete restrict,
    external_order_id text,
    status text not null default 'pending'
        check (status in ('pending', 'reserved', 'paid', 'fulfilled', 'cancelled', 'exception')),
    payment_status text not null default 'pending'
        check (payment_status in ('pending', 'authorized', 'paid', 'failed', 'refunded', 'partially_refunded')),
    fulfillment_status text not null default 'pending'
        check (fulfillment_status in ('pending', 'ready', 'shipped', 'delivered', 'cancelled', 'returned')),
    currency_code char(3) not null default 'CLP' check (currency_code = upper(currency_code)),
    subtotal_amount numeric(12,2) not null default 0 check (subtotal_amount >= 0),
    discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
    shipping_amount numeric(12,2) not null default 0 check (shipping_amount >= 0),
    tax_amount numeric(12,2) not null default 0 check (tax_amount >= 0),
    total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
    shipping_snapshot jsonb,
    placed_at timestamptz not null default now(),
    paid_at timestamptz,
    cancelled_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create unique index orders_channel_external_key on app.orders(channel_id, external_order_id)
    where external_order_id is not null;
create index orders_customer_status_idx on app.orders(customer_id, status, created_at desc);
create index orders_channel_status_idx on app.orders(channel_id, status, created_at desc);

create table app.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references app.orders(id) on delete restrict,
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    sku_snapshot text not null,
    name_snapshot text not null,
    quantity integer not null check (quantity > 0),
    unit_price_amount numeric(12,2) not null check (unit_price_amount >= 0),
    discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
    tax_amount numeric(12,2) not null default 0 check (tax_amount >= 0),
    line_total_amount numeric(12,2) not null check (line_total_amount >= 0),
    created_at timestamptz not null default now(),
    unique (order_id, variant_id)
);
create index order_items_order_idx on app.order_items(order_id);
create index order_items_variant_idx on app.order_items(variant_id);

create table app.inventory (
    variant_id uuid primary key references app.product_variants(id) on delete restrict,
    on_hand integer not null default 0 check (on_hand >= 0),
    reserved integer not null default 0 check (reserved >= 0),
    safety_stock integer not null default 1 check (safety_stock >= 0),
    reorder_point integer not null default 0 check (reorder_point >= 0),
    available integer generated always as (on_hand - reserved) stored,
    updated_at timestamptz not null default now(),
    constraint inventory_reserved_capacity_check check (reserved <= on_hand)
);
create index inventory_low_stock_idx on app.inventory(available, reorder_point);

create table app.inventory_operations (
    id uuid primary key default gen_random_uuid(),
    idempotency_key text not null unique,
    operation_type text not null check (operation_type in ('initial_balance', 'adjustment', 'reserve', 'release', 'sale', 'receipt', 'return', 'expire')),
    variant_id uuid references app.product_variants(id) on delete restrict,
    quantity integer,
    actor_user_id uuid references auth.users(id) on delete set null,
    source_type text,
    source_id uuid,
    status text not null default 'running' check (status in ('running', 'succeeded', 'failed')),
    result jsonb,
    created_at timestamptz not null default now(),
    completed_at timestamptz
);
create index inventory_operations_source_idx on app.inventory_operations(source_type, source_id);

create table app.inventory_movements (
    id uuid primary key default gen_random_uuid(),
    operation_id uuid not null references app.inventory_operations(id) on delete restrict,
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    on_hand_delta integer not null default 0,
    reserved_delta integer not null default 0,
    reason text not null check (btrim(reason) <> ''),
    reference_type text,
    reference_id uuid,
    actor_user_id uuid references auth.users(id) on delete set null,
    occurred_at timestamptz not null default now(),
    constraint inventory_movements_nonzero_check check (on_hand_delta <> 0 or reserved_delta <> 0)
);
create index inventory_movements_variant_time_idx
    on app.inventory_movements(variant_id, occurred_at desc);
create index inventory_movements_reference_idx
    on app.inventory_movements(reference_type, reference_id);

create table app.inventory_reservations (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references app.orders(id) on delete restrict,
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    quantity integer not null check (quantity > 0),
    status text not null default 'active' check (status in ('active', 'released', 'consumed', 'expired')),
    expires_at timestamptz not null,
    reserved_at timestamptz not null default now(),
    released_at timestamptz,
    consumed_at timestamptz,
    created_at timestamptz not null default now()
);
create unique index inventory_reservations_active_key
    on app.inventory_reservations(order_id, variant_id) where status = 'active';
create index inventory_reservations_expiry_idx
    on app.inventory_reservations(status, expires_at) where status = 'active';

create table app.payment_attempts (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references app.orders(id) on delete restrict,
    provider text not null,
    external_payment_id text,
    status text not null default 'pending'
        check (status in ('pending', 'authorized', 'paid', 'failed', 'cancelled', 'refunded')),
    amount numeric(12,2) not null check (amount >= 0),
    currency_code char(3) not null default 'CLP' check (currency_code = upper(currency_code)),
    requested_at timestamptz not null default now(),
    confirmed_at timestamptz,
    raw_reference jsonb,
    created_at timestamptz not null default now()
);
create unique index payment_attempts_provider_external_key
    on app.payment_attempts(provider, external_payment_id) where external_payment_id is not null;
create index payment_attempts_order_status_idx on app.payment_attempts(order_id, status);

create table app.refunds (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references app.orders(id) on delete restrict,
    payment_attempt_id uuid not null references app.payment_attempts(id) on delete restrict,
    external_refund_id text,
    amount numeric(12,2) not null check (amount > 0),
    status text not null default 'pending' check (status in ('pending', 'completed', 'failed', 'cancelled')),
    reason text,
    requested_at timestamptz not null default now(),
    completed_at timestamptz,
    created_at timestamptz not null default now()
);
create unique index refunds_external_key on app.refunds(external_refund_id)
    where external_refund_id is not null;

create table app.shipments (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references app.orders(id) on delete restrict,
    method text not null check (method in ('pickup', 'courier', 'mercado_envios')),
    status text not null default 'pending'
        check (status in ('pending', 'ready', 'shipped', 'delivered', 'cancelled')),
    tracking_number text,
    address_snapshot jsonb,
    shipped_at timestamptz,
    delivered_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index shipments_order_status_idx on app.shipments(order_id, status);

create table app.returns (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references app.orders(id) on delete restrict,
    return_number text not null unique,
    status text not null default 'requested'
        check (status in ('requested', 'approved', 'received', 'rejected', 'completed')),
    reason text not null,
    requested_at timestamptz not null default now(),
    received_at timestamptz,
    decided_at timestamptz,
    notes text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index returns_order_status_idx on app.returns(order_id, status);

create table app.return_items (
    id uuid primary key default gen_random_uuid(),
    return_id uuid not null references app.returns(id) on delete restrict,
    order_item_id uuid not null references app.order_items(id) on delete restrict,
    quantity_requested integer not null check (quantity_requested > 0),
    quantity_received integer not null default 0 check (quantity_received >= 0),
    quantity_restocked integer not null default 0 check (quantity_restocked >= 0),
    inspection_status text not null default 'pending'
        check (inspection_status in ('pending', 'accepted', 'damaged', 'rejected')),
    inspection_notes text,
    created_at timestamptz not null default now(),
    constraint return_items_quantities_check check (
        quantity_received <= quantity_requested and quantity_restocked <= quantity_received
    )
);
create index return_items_return_idx on app.return_items(return_id);

create table app.warranty_claims (
    id uuid primary key default gen_random_uuid(),
    order_item_id uuid not null references app.order_items(id) on delete restrict,
    return_id uuid references app.returns(id) on delete restrict,
    claim_number text not null unique,
    status text not null default 'opened'
        check (status in ('opened', 'reviewing', 'approved', 'rejected', 'resolved', 'closed')),
    issue_description text not null,
    resolution text,
    opened_at timestamptz not null default now(),
    closed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table app.ml_connections (
    id uuid primary key default gen_random_uuid(),
    seller_id text not null unique,
    nickname text,
    status text not null default 'active' check (status in ('active', 'expired', 'disconnected', 'error')),
    token_reference text not null,
    connected_at timestamptz not null default now(),
    last_refreshed_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table app.ml_listings (
    id uuid primary key default gen_random_uuid(),
    connection_id uuid not null references app.ml_connections(id) on delete restrict,
    variant_id uuid not null references app.product_variants(id) on delete restrict,
    item_id text not null,
    variation_id text,
    status text not null default 'active' check (status in ('active', 'paused', 'closed', 'error')),
    last_published_available integer,
    last_published_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (connection_id, item_id, variation_id),
    unique (connection_id, variant_id)
);

create table app.integration_events (
    id uuid primary key default gen_random_uuid(),
    provider text not null,
    event_type text not null,
    external_event_id text not null,
    resource_id text,
    payload jsonb not null,
    received_at timestamptz not null default now(),
    status text not null default 'received'
        check (status in ('received', 'processing', 'processed', 'failed', 'ignored')),
    processed_at timestamptz,
    error_message text,
    unique (provider, external_event_id)
);
create index integration_events_status_idx on app.integration_events(status, received_at);

create table app.integration_jobs (
    id uuid primary key default gen_random_uuid(),
    job_type text not null,
    entity_type text not null,
    entity_id uuid,
    deduplication_key text not null unique,
    desired_version bigint,
    status text not null default 'pending'
        check (status in ('pending', 'running', 'succeeded', 'failed')),
    attempts integer not null default 0 check (attempts >= 0),
    next_attempt_at timestamptz not null default now(),
    locked_at timestamptz,
    last_error text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);
create index integration_jobs_queue_idx on app.integration_jobs(status, next_attempt_at);

create table app.integration_logs (
    id uuid primary key default gen_random_uuid(),
    job_id uuid references app.integration_jobs(id) on delete set null,
    event_id uuid references app.integration_events(id) on delete set null,
    request_summary jsonb,
    response_summary jsonb,
    http_status integer,
    succeeded boolean not null,
    occurred_at timestamptz not null default now()
);
create index integration_logs_job_time_idx on app.integration_logs(job_id, occurred_at desc);

create table app.staff_roles (
    id uuid primary key default gen_random_uuid(),
    auth_user_id uuid not null references auth.users(id) on delete cascade,
    role text not null check (role in ('owner', 'admin', 'operator', 'support')),
    active boolean not null default true,
    granted_by uuid references auth.users(id) on delete set null,
    granted_at timestamptz not null default now(),
    unique (auth_user_id, role)
);

create table app.audit_events (
    id uuid primary key default gen_random_uuid(),
    actor_user_id uuid references auth.users(id) on delete set null,
    action text not null,
    entity_type text not null,
    entity_id uuid,
    before_data jsonb,
    after_data jsonb,
    request_id text,
    occurred_at timestamptz not null default now()
);
create index audit_events_entity_time_idx on app.audit_events(entity_type, entity_id, occurred_at desc);
create index audit_events_actor_time_idx on app.audit_events(actor_user_id, occurred_at desc);

create or replace function app.touch_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, app
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

alter table app.schema_migrations enable row level security;
revoke all on table app.schema_migrations from public, anon, authenticated;
grant all on table app.schema_migrations to service_role;

do $$
declare
    table_name text;
begin
    foreach table_name in array array[
        'categories', 'product_brands', 'products', 'product_variants',
        'motorcycle_makes', 'motorcycle_models', 'motorcycle_versions',
        'suppliers', 'supplier_products', 'purchase_orders', 'goods_receipts',
        'customers', 'sales_channels', 'orders', 'shipments', 'returns',
        'warranty_claims', 'ml_connections', 'ml_listings', 'integration_jobs'
    ] loop
        execute format(
            'create trigger %I before update on app.%I for each row execute function app.touch_updated_at()',
            table_name || '_touch_updated_at', table_name
        );
    end loop;
end;
$$;

create or replace function app.ensure_inventory_row()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, app
as $$
begin
    insert into app.inventory(variant_id) values (new.id) on conflict (variant_id) do nothing;
    return new;
end;
$$;

create trigger product_variants_create_inventory
after insert on app.product_variants
for each row execute function app.ensure_inventory_row();

create or replace function app.prevent_price_overlap()
returns trigger
language plpgsql
set search_path = pg_catalog, app
as $$
begin
    if exists (
        select 1
        from app.variant_prices p
        where p.variant_id = new.variant_id
          and p.channel_id = new.channel_id
          and p.active
          and p.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
          and tstzrange(p.valid_from, p.valid_to, '[)') && tstzrange(new.valid_from, new.valid_to, '[)')
    ) then
        raise exception 'Overlapping active price for variant % and channel %', new.variant_id, new.channel_id
            using errcode = '23P01';
    end if;
    return new;
end;
$$;

create trigger variant_prices_no_overlap
before insert or update on app.variant_prices
for each row execute function app.prevent_price_overlap();

create or replace function app.is_staff()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, app, auth, public
as $$
    select session_user in ('postgres', 'supabase_admin')
        or current_setting('request.jwt.claim.role', true) = 'service_role'
        or exists (
            select 1 from app.staff_roles
            where auth_user_id = auth.uid() and active
        );
$$;

create or replace function app.auth_customer_id()
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, app, auth, public
as $$
    select id from app.customers where auth_user_id = auth.uid() limit 1;
$$;

-- RLS is enabled on every business table. Direct API grants are intentionally
-- revoked; callers use the safe api views/functions below.
do $$
declare
    table_name text;
begin
    foreach table_name in array array[
        'categories', 'product_brands', 'products', 'product_variants', 'product_images',
        'motorcycle_makes', 'motorcycle_models', 'motorcycle_versions', 'product_fitments',
        'part_references', 'suppliers', 'supplier_products', 'purchase_orders',
        'purchase_order_items', 'goods_receipts', 'goods_receipt_items', 'customers',
        'sales_channels', 'variant_prices', 'orders', 'order_items', 'inventory',
        'inventory_operations', 'inventory_movements', 'inventory_reservations',
        'payment_attempts', 'refunds', 'shipments', 'returns', 'return_items',
        'warranty_claims', 'ml_connections', 'ml_listings', 'integration_events',
        'integration_jobs', 'integration_logs', 'staff_roles', 'audit_events'
    ] loop
        execute format('alter table app.%I enable row level security', table_name);
        execute format('revoke all on table app.%I from public, anon, authenticated', table_name);
        execute format('grant all on table app.%I to service_role', table_name);
    end loop;
end;
$$;

grant usage on schema app to service_role;
grant select on app.categories, app.product_brands, app.products, app.product_variants,
    app.product_images, app.motorcycle_makes, app.motorcycle_models,
    app.motorcycle_versions, app.product_fitments, app.part_references,
    app.sales_channels, app.variant_prices to service_role;

create policy categories_staff_all on app.categories for all to service_role using (true) with check (true);
create policy product_brands_staff_all on app.product_brands for all to service_role using (true) with check (true);
create policy products_staff_all on app.products for all to service_role using (true) with check (true);
create policy product_variants_staff_all on app.product_variants for all to service_role using (true) with check (true);
create policy product_images_staff_all on app.product_images for all to service_role using (true) with check (true);
create policy motorcycle_makes_staff_all on app.motorcycle_makes for all to service_role using (true) with check (true);
create policy motorcycle_models_staff_all on app.motorcycle_models for all to service_role using (true) with check (true);
create policy motorcycle_versions_staff_all on app.motorcycle_versions for all to service_role using (true) with check (true);
create policy product_fitments_staff_all on app.product_fitments for all to service_role using (true) with check (true);
create policy part_references_staff_all on app.part_references for all to service_role using (true) with check (true);
create policy customers_own_select on app.customers for select to authenticated using (auth_user_id = auth.uid() or app.is_staff());
create policy customers_own_update on app.customers for update to authenticated using (auth_user_id = auth.uid() or app.is_staff()) with check (auth_user_id = auth.uid() or app.is_staff());
create policy customers_staff_all on app.customers for all to service_role using (true) with check (true);
create policy orders_own_select on app.orders for select to authenticated using (customer_id = app.auth_customer_id() or app.is_staff());
create policy orders_staff_all on app.orders for all to service_role using (true) with check (true);
create policy order_items_own_select on app.order_items for select to authenticated using (exists (select 1 from app.orders o where o.id = order_id and (o.customer_id = app.auth_customer_id() or app.is_staff())));
create policy order_items_staff_all on app.order_items for all to service_role using (true) with check (true);
create policy reservations_own_select on app.inventory_reservations for select to authenticated using (exists (select 1 from app.orders o where o.id = order_id and (o.customer_id = app.auth_customer_id() or app.is_staff())));
create policy reservations_staff_all on app.inventory_reservations for all to service_role using (true) with check (true);
create policy payments_own_select on app.payment_attempts for select to authenticated using (exists (select 1 from app.orders o where o.id = order_id and (o.customer_id = app.auth_customer_id() or app.is_staff())));
create policy payments_staff_all on app.payment_attempts for all to service_role using (true) with check (true);
create policy refunds_own_select on app.refunds for select to authenticated using (exists (select 1 from app.orders o where o.id = order_id and (o.customer_id = app.auth_customer_id() or app.is_staff())));
create policy refunds_staff_all on app.refunds for all to service_role using (true) with check (true);
create policy shipments_own_select on app.shipments for select to authenticated using (exists (select 1 from app.orders o where o.id = order_id and (o.customer_id = app.auth_customer_id() or app.is_staff())));
create policy shipments_staff_all on app.shipments for all to service_role using (true) with check (true);
create policy returns_own_select on app.returns for select to authenticated using (exists (select 1 from app.orders o where o.id = order_id and (o.customer_id = app.auth_customer_id() or app.is_staff())));
create policy returns_staff_all on app.returns for all to service_role using (true) with check (true);
create policy return_items_own_select on app.return_items for select to authenticated using (exists (select 1 from app.returns r join app.orders o on o.id = r.order_id where r.id = return_id and (o.customer_id = app.auth_customer_id() or app.is_staff())));
create policy return_items_staff_all on app.return_items for all to service_role using (true) with check (true);
create policy warranty_own_select on app.warranty_claims for select to authenticated using (exists (select 1 from app.order_items oi join app.orders o on o.id = oi.order_id where oi.id = order_item_id and (o.customer_id = app.auth_customer_id() or app.is_staff())));
create policy warranty_staff_all on app.warranty_claims for all to service_role using (true) with check (true);
create policy staff_roles_self_select on app.staff_roles for select to authenticated using (auth_user_id = auth.uid() or app.is_staff());
create policy staff_roles_service_all on app.staff_roles for all to service_role using (true) with check (true);

create or replace function api.create_order(
    p_channel_code text,
    p_customer_id uuid,
    p_lines jsonb,
    p_shipping_snapshot jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, app, auth, public
as $$
declare
    v_channel app.sales_channels;
    v_order app.orders;
    v_line jsonb;
    v_variant app.product_variants;
    v_price app.variant_prices;
    v_quantity integer;
    v_subtotal numeric(12,2) := 0;
    v_customer uuid := p_customer_id;
begin
    if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
        raise exception 'At least one order line is required' using errcode = '22023';
    end if;
    if not app.is_staff() and v_customer is not null and not exists (
        select 1 from app.customers where id = v_customer and auth_user_id = auth.uid()
    ) then
        raise exception 'Customer does not belong to the authenticated user' using errcode = '42501';
    end if;
    select * into v_channel from app.sales_channels where code = p_channel_code and active for share;
    if not found then raise exception 'Unknown or inactive sales channel' using errcode = '22023'; end if;

    insert into app.orders(customer_id, channel_id, shipping_snapshot)
    values (v_customer, v_channel.id, p_shipping_snapshot)
    returning * into v_order;

    for v_line in select value from jsonb_array_elements(p_lines) loop
        if not (v_line ? 'variant_id') or not (v_line ? 'quantity') then
            raise exception 'Each line requires variant_id and quantity' using errcode = '22023';
        end if;
        v_quantity := (v_line->>'quantity')::integer;
        if v_quantity <= 0 then raise exception 'Quantity must be positive' using errcode = '22023'; end if;
        select * into v_variant from app.product_variants where id = (v_line->>'variant_id')::uuid and active for share;
        if not found then raise exception 'Variant is not active' using errcode = '22023'; end if;
        select * into v_price from app.variant_prices
        where variant_id = v_variant.id and channel_id = v_channel.id and active
          and valid_from <= now() and (valid_to is null or valid_to > now())
        order by valid_from desc limit 1;
        if not found then raise exception 'No active price for SKU %', v_variant.sku using errcode = '22023'; end if;
        insert into app.order_items(order_id, variant_id, sku_snapshot, name_snapshot, quantity, unit_price_amount, line_total_amount)
        values (v_order.id, v_variant.id, v_variant.sku, v_variant.name, v_quantity,
                v_price.unit_price_amount, v_price.unit_price_amount * v_quantity);
        v_subtotal := v_subtotal + v_price.unit_price_amount * v_quantity;
    end loop;
    update app.orders set subtotal_amount = v_subtotal, total_amount = v_subtotal where id = v_order.id;
    return jsonb_build_object('order_id', v_order.id, 'order_number', v_order.order_number,
                              'status', 'pending', 'total_amount', v_subtotal,
                              'currency_code', v_order.currency_code);
end;
$$;

create or replace function api.reserve_order(p_order_id uuid, p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, app, auth, public
as $$
declare
    v_existing app.inventory_operations;
    v_order app.orders;
    v_line record;
    v_inventory app.inventory;
    v_operation_id uuid;
    v_expires_at timestamptz := now() + interval '15 minutes';
    v_count integer := 0;
    v_result jsonb;
begin
    if p_idempotency_key is null or btrim(p_idempotency_key) = '' then
        raise exception 'Idempotency key is required' using errcode = '22023';
    end if;
    select * into v_existing from app.inventory_operations where idempotency_key = p_idempotency_key;
    if found then
        if v_existing.source_id <> p_order_id or v_existing.operation_type <> 'reserve' then
            raise exception 'Idempotency key was used with different parameters' using errcode = '23505';
        end if;
        return v_existing.result;
    end if;
    select * into v_order from app.orders where id = p_order_id for update;
    if not found then raise exception 'Order not found' using errcode = 'P0002'; end if;
    if not app.is_staff() and not exists (
        select 1 from app.customers c where c.id = v_order.customer_id and c.auth_user_id = auth.uid()
    ) then raise exception 'Order does not belong to the authenticated user' using errcode = '42501'; end if;
    if v_order.status = 'reserved' then
        select max(expires_at) into v_expires_at from app.inventory_reservations
        where order_id = p_order_id and status = 'active';
        return jsonb_build_object('order_id', p_order_id, 'status', 'reserved', 'expires_at', v_expires_at);
    end if;
    if v_order.status <> 'pending' then raise exception 'Order cannot be reserved from status %', v_order.status using errcode = '55000'; end if;

    insert into app.inventory_operations(idempotency_key, operation_type, actor_user_id, source_type, source_id)
    values (p_idempotency_key, 'reserve', auth.uid(), 'order', p_order_id)
    returning id into v_operation_id;

    for v_line in select oi.* from app.order_items oi where oi.order_id = p_order_id order by oi.variant_id for update loop
        select * into v_inventory from app.inventory where variant_id = v_line.variant_id for update;
        if not found or v_inventory.on_hand - v_inventory.reserved < v_line.quantity then
            raise exception 'Insufficient inventory for variant %', v_line.variant_id using errcode = 'P0001';
        end if;
        update app.inventory set reserved = reserved + v_line.quantity, updated_at = now()
        where variant_id = v_line.variant_id;
        insert into app.inventory_reservations(order_id, variant_id, quantity, expires_at)
        values (p_order_id, v_line.variant_id, v_line.quantity, v_expires_at);
        insert into app.inventory_movements(operation_id, variant_id, reserved_delta, reason, reference_type, reference_id, actor_user_id)
        values (v_operation_id, v_line.variant_id, v_line.quantity, 'checkout reservation', 'order', p_order_id, auth.uid());
        v_count := v_count + 1;
    end loop;
    if v_count = 0 then raise exception 'Order has no lines' using errcode = '22023'; end if;
    update app.orders set status = 'reserved' where id = p_order_id;
    v_result := jsonb_build_object('operation_id', v_operation_id, 'order_id', p_order_id,
                                   'status', 'reserved', 'expires_at', v_expires_at, 'line_count', v_count);
    update app.inventory_operations set status = 'succeeded', result = v_result, completed_at = now() where id = v_operation_id;
    return v_result;
end;
$$;

create or replace function api.release_reservation(p_order_id uuid, p_idempotency_key text, p_expired boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, app, auth, public
as $$
declare
    v_existing app.inventory_operations;
    v_order app.orders;
    v_reservation record;
    v_operation_id uuid;
    v_status text := case when p_expired then 'expired' else 'released' end;
    v_result jsonb;
    v_count integer := 0;
begin
    select * into v_existing from app.inventory_operations where idempotency_key = p_idempotency_key;
    if found then return v_existing.result; end if;
    select * into v_order from app.orders where id = p_order_id for update;
    if not found then raise exception 'Order not found' using errcode = 'P0002'; end if;
    if not app.is_staff() and not exists (select 1 from app.customers where id = v_order.customer_id and auth_user_id = auth.uid()) then
        raise exception 'Order does not belong to the authenticated user' using errcode = '42501';
    end if;
    if v_order.status in ('paid', 'fulfilled') then raise exception 'Paid order cannot release inventory' using errcode = '55000'; end if;
    insert into app.inventory_operations(idempotency_key, operation_type, actor_user_id, source_type, source_id)
    values (p_idempotency_key, case when p_expired then 'expire' else 'release' end, auth.uid(), 'order', p_order_id)
    returning id into v_operation_id;
    for v_reservation in
        select r.* from app.inventory_reservations r where r.order_id = p_order_id and r.status = 'active' order by r.variant_id for update
    loop
        update app.inventory set reserved = reserved - v_reservation.quantity, updated_at = now()
        where variant_id = v_reservation.variant_id;
        update app.inventory_reservations set status = v_status, released_at = now() where id = v_reservation.id;
        insert into app.inventory_movements(operation_id, variant_id, reserved_delta, reason, reference_type, reference_id, actor_user_id)
        values (v_operation_id, v_reservation.variant_id, -v_reservation.quantity,
                case when p_expired then 'reservation expired' else 'reservation released' end,
                'order', p_order_id, auth.uid());
        v_count := v_count + 1;
    end loop;
    update app.orders set status = 'pending' where id = p_order_id and status = 'reserved';
    v_result := jsonb_build_object('operation_id', v_operation_id, 'order_id', p_order_id, 'status', v_status, 'line_count', v_count);
    update app.inventory_operations set status = 'succeeded', result = v_result, completed_at = now() where id = v_operation_id;
    return v_result;
end;
$$;

create or replace function api.expire_reservations()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, app, auth, public
as $$
declare
    v_reservation record;
    v_count integer := 0;
begin
    if not app.is_staff() then raise exception 'Staff authorization required' using errcode = '42501'; end if;
    for v_reservation in
        select distinct order_id from app.inventory_reservations where status = 'active' and expires_at <= now() order by order_id
    loop
        perform api.release_reservation(v_reservation.order_id, 'expiry:' || v_reservation.order_id::text || ':' || to_char(now(), 'YYYYMMDDHH24MISS'), true);
        v_count := v_count + 1;
    end loop;
    return v_count;
end;
$$;

create or replace function api.confirm_order_sale(p_order_id uuid, p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, app, auth, public
as $$
declare
    v_existing app.inventory_operations;
    v_order app.orders;
    v_line record;
    v_inventory app.inventory;
    v_reservation app.inventory_reservations;
    v_operation_id uuid;
    v_result jsonb;
    v_count integer := 0;
begin
    if not app.is_staff() then raise exception 'Staff authorization required' using errcode = '42501'; end if;
    select * into v_existing from app.inventory_operations where idempotency_key = p_idempotency_key;
    if found then return v_existing.result; end if;
    select * into v_order from app.orders where id = p_order_id for update;
    if not found then raise exception 'Order not found' using errcode = 'P0002'; end if;
    if v_order.status in ('paid', 'fulfilled') then raise exception 'Order already confirmed' using errcode = '55000'; end if;
    insert into app.inventory_operations(idempotency_key, operation_type, actor_user_id, source_type, source_id)
    values (p_idempotency_key, 'sale', auth.uid(), 'order', p_order_id)
    returning id into v_operation_id;
    for v_line in select oi.* from app.order_items oi where oi.order_id = p_order_id order by oi.variant_id for update loop
        select * into v_inventory from app.inventory where variant_id = v_line.variant_id for update;
        if not found then raise exception 'Inventory row missing for variant %', v_line.variant_id; end if;
        select * into v_reservation from app.inventory_reservations
        where order_id = p_order_id and variant_id = v_line.variant_id and status = 'active' for update;
        if found then
            if v_reservation.quantity <> v_line.quantity then raise exception 'Reservation quantity mismatch for variant %', v_line.variant_id; end if;
            update app.inventory set on_hand = on_hand - v_line.quantity, reserved = reserved - v_line.quantity, updated_at = now()
            where variant_id = v_line.variant_id and on_hand >= v_line.quantity and reserved >= v_line.quantity;
            if not found then raise exception 'Inventory changed before sale for variant %', v_line.variant_id; end if;
            update app.inventory_reservations set status = 'consumed', consumed_at = now() where id = v_reservation.id;
            insert into app.inventory_movements(operation_id, variant_id, on_hand_delta, reserved_delta, reason, reference_type, reference_id, actor_user_id)
            values (v_operation_id, v_line.variant_id, -v_line.quantity, -v_line.quantity, 'confirmed sale', 'order', p_order_id, auth.uid());
        else
            update app.inventory set on_hand = on_hand - v_line.quantity, updated_at = now()
            where variant_id = v_line.variant_id and on_hand - reserved >= v_line.quantity;
            if not found then raise exception 'Insufficient inventory for direct sale of variant %', v_line.variant_id; end if;
            insert into app.inventory_movements(operation_id, variant_id, on_hand_delta, reason, reference_type, reference_id, actor_user_id)
            values (v_operation_id, v_line.variant_id, -v_line.quantity, 'confirmed direct sale', 'order', p_order_id, auth.uid());
        end if;
        v_count := v_count + 1;
    end loop;
    update app.orders set status = 'paid', payment_status = 'paid', paid_at = coalesce(paid_at, now()) where id = p_order_id;
    v_result := jsonb_build_object('operation_id', v_operation_id, 'order_id', p_order_id, 'status', 'paid', 'line_count', v_count);
    update app.inventory_operations set status = 'succeeded', result = v_result, completed_at = now() where id = v_operation_id;
    return v_result;
end;
$$;

create or replace function api.adjust_inventory(p_variant_id uuid, p_delta integer, p_reason text, p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, app, auth, public
as $$
declare
    v_existing app.inventory_operations;
    v_inventory app.inventory;
    v_operation_id uuid;
    v_result jsonb;
begin
    if not app.is_staff() then raise exception 'Staff authorization required' using errcode = '42501'; end if;
    if p_delta = 0 or p_reason is null or btrim(p_reason) = '' then raise exception 'Non-zero delta and reason are required' using errcode = '22023'; end if;
    select * into v_existing from app.inventory_operations where idempotency_key = p_idempotency_key;
    if found then return v_existing.result; end if;
    select * into v_inventory from app.inventory where variant_id = p_variant_id for update;
    if not found then raise exception 'Inventory row not found' using errcode = 'P0002'; end if;
    if v_inventory.on_hand + p_delta < v_inventory.reserved then raise exception 'Adjustment would make on_hand lower than reserved' using errcode = '23514'; end if;
    insert into app.inventory_operations(idempotency_key, operation_type, variant_id, quantity, actor_user_id, source_type, source_id)
    values (p_idempotency_key, 'adjustment', p_variant_id, abs(p_delta), auth.uid(), 'manual', p_variant_id)
    returning id into v_operation_id;
    update app.inventory set on_hand = on_hand + p_delta, updated_at = now() where variant_id = p_variant_id;
    insert into app.inventory_movements(operation_id, variant_id, on_hand_delta, reason, reference_type, reference_id, actor_user_id)
    values (v_operation_id, p_variant_id, p_delta, p_reason, 'manual', p_variant_id, auth.uid());
    v_result := jsonb_build_object('operation_id', v_operation_id, 'variant_id', p_variant_id,
                                   'on_hand_delta', p_delta, 'status', 'succeeded');
    update app.inventory_operations set status = 'succeeded', result = v_result, completed_at = now() where id = v_operation_id;
    return v_result;
end;
$$;

create or replace function api.receive_purchase(p_receipt_id uuid, p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, app, auth, public
as $$
declare
    v_existing app.inventory_operations;
    v_receipt app.goods_receipts;
    v_item record;
    v_inventory app.inventory;
    v_operation_id uuid;
    v_result jsonb;
    v_count integer := 0;
begin
    if not app.is_staff() then raise exception 'Staff authorization required' using errcode = '42501'; end if;
    select * into v_existing from app.inventory_operations where idempotency_key = p_idempotency_key;
    if found then return v_existing.result; end if;
    select * into v_receipt from app.goods_receipts where id = p_receipt_id for update;
    if not found then raise exception 'Receipt not found' using errcode = 'P0002'; end if;
    if v_receipt.status = 'posted' then raise exception 'Receipt already posted' using errcode = '55000'; end if;
    insert into app.inventory_operations(idempotency_key, operation_type, actor_user_id, source_type, source_id)
    values (p_idempotency_key, 'receipt', auth.uid(), 'goods_receipt', p_receipt_id)
    returning id into v_operation_id;
    for v_item in
        select gri.*, poi.variant_id, poi.quantity_ordered, poi.quantity_received
        from app.goods_receipt_items gri
        join app.purchase_order_items poi on poi.id = gri.purchase_order_item_id
        where gri.goods_receipt_id = p_receipt_id
        order by poi.variant_id
        for update of poi
    loop
        if v_item.quantity_received + v_item.quantity_accepted > v_item.quantity_ordered then
            raise exception 'Receipt exceeds ordered quantity for item %', v_item.purchase_order_item_id using errcode = '23514';
        end if;
        if v_item.quantity_accepted > 0 then
            select * into v_inventory from app.inventory where variant_id = v_item.variant_id for update;
            update app.inventory set on_hand = on_hand + v_item.quantity_accepted, updated_at = now()
            where variant_id = v_item.variant_id;
            update app.purchase_order_items set quantity_received = quantity_received + v_item.quantity_accepted
            where id = v_item.purchase_order_item_id;
            insert into app.inventory_movements(operation_id, variant_id, on_hand_delta, reason, reference_type, reference_id, actor_user_id)
            values (v_operation_id, v_item.variant_id, v_item.quantity_accepted, 'purchase receipt', 'goods_receipt', p_receipt_id, auth.uid());
            v_count := v_count + 1;
        end if;
    end loop;
    update app.goods_receipts set status = 'posted', received_at = coalesce(received_at, now()), received_by = coalesce(received_by, auth.uid()) where id = p_receipt_id;
    update app.purchase_orders po set status = case when not exists (
        select 1 from app.purchase_order_items poi where poi.purchase_order_id = po.id and poi.quantity_received < poi.quantity_ordered
    ) then 'received' else 'partially_received' end where po.id = v_receipt.purchase_order_id;
    v_result := jsonb_build_object('operation_id', v_operation_id, 'receipt_id', p_receipt_id, 'status', 'posted', 'line_count', v_count);
    update app.inventory_operations set status = 'succeeded', result = v_result, completed_at = now() where id = v_operation_id;
    return v_result;
end;
$$;

create or replace function api.register_return(p_return_id uuid, p_idempotency_key text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, app, auth, public
as $$
declare
    v_existing app.inventory_operations;
    v_return app.returns;
    v_item record;
    v_operation_id uuid;
    v_result jsonb;
    v_count integer := 0;
begin
    if not app.is_staff() then raise exception 'Staff authorization required' using errcode = '42501'; end if;
    select * into v_existing from app.inventory_operations where idempotency_key = p_idempotency_key;
    if found then return v_existing.result; end if;
    select * into v_return from app.returns where id = p_return_id for update;
    if not found then raise exception 'Return not found' using errcode = 'P0002'; end if;
    if v_return.status = 'completed' then raise exception 'Return already completed' using errcode = '55000'; end if;
    insert into app.inventory_operations(idempotency_key, operation_type, actor_user_id, source_type, source_id)
    values (p_idempotency_key, 'return', auth.uid(), 'return', p_return_id)
    returning id into v_operation_id;
    for v_item in select ri.*, oi.variant_id from app.return_items ri join app.order_items oi on oi.id = ri.order_item_id
                  where ri.return_id = p_return_id and ri.quantity_restocked > 0 order by oi.variant_id for update of ri
    loop
        update app.inventory set on_hand = on_hand + v_item.quantity_restocked, updated_at = now()
        where variant_id = v_item.variant_id;
        insert into app.inventory_movements(operation_id, variant_id, on_hand_delta, reason, reference_type, reference_id, actor_user_id)
        values (v_operation_id, v_item.variant_id, v_item.quantity_restocked, 'accepted return', 'return', p_return_id, auth.uid());
        v_count := v_count + 1;
    end loop;
    update app.returns set status = 'completed', decided_at = coalesce(decided_at, now()) where id = p_return_id;
    v_result := jsonb_build_object('operation_id', v_operation_id, 'return_id', p_return_id, 'status', 'completed', 'line_count', v_count);
    update app.inventory_operations set status = 'succeeded', result = v_result, completed_at = now() where id = v_operation_id;
    return v_result;
end;
$$;

create or replace view api.v_catalog as
select p.id as product_id, p.slug as product_slug, p.name as product_name,
       p.description, c.slug as category_slug, b.slug as brand_slug,
       pv.id as variant_id, pv.sku, pv.name as variant_name, pv.attributes,
       price.unit_price_amount, price.currency_code,
       greatest(0, i.on_hand - i.reserved - i.safety_stock) as publishable_available,
       i.available, pi.storage_path as image_storage_path, pi.alt_text,
       pi.sort_order
from app.products p
join app.product_variants pv on pv.product_id = p.id and pv.active
join app.categories c on c.id = p.category_id and c.active
left join app.product_brands b on b.id = p.brand_id and b.active
join app.inventory i on i.variant_id = pv.id
left join lateral (
    select vp.unit_price_amount, vp.currency_code
    from app.variant_prices vp
    join app.sales_channels sc on sc.id = vp.channel_id and sc.code = 'web'
    where vp.variant_id = pv.id and vp.active and vp.valid_from <= now()
      and (vp.valid_to is null or vp.valid_to > now())
    order by vp.valid_from desc limit 1
) price on true
left join app.product_images pi on pi.variant_id = pv.id and pi.is_primary
where p.status = 'published';

create or replace view api.v_product_fitments as
select pv.id as variant_id, pv.sku, mm.name as motorcycle_make,
       mo.name as motorcycle_model, mv.name as motorcycle_version,
       mv.engine_code, coalesce(pf.year_from, mv.year_from) as year_from,
       coalesce(pf.year_to, mv.year_to) as year_to, pf.notes, pf.source_type,
       pf.verified_at
from app.product_fitments pf
join app.product_variants pv on pv.id = pf.variant_id and pv.active
join app.motorcycle_versions mv on mv.id = pf.motorcycle_version_id and mv.active
join app.motorcycle_models mo on mo.id = mv.model_id and mo.active
join app.motorcycle_makes mm on mm.id = mo.make_id and mm.active;

create or replace view api.v_order_summary as
select o.id as order_id, o.order_number, o.status, o.payment_status,
       o.fulfillment_status, o.currency_code, o.subtotal_amount,
       o.shipping_amount, o.tax_amount, o.total_amount, o.placed_at,
       jsonb_agg(jsonb_build_object(
           'variant_id', oi.variant_id, 'sku', oi.sku_snapshot,
           'name', oi.name_snapshot, 'quantity', oi.quantity,
           'unit_price_amount', oi.unit_price_amount,
           'line_total_amount', oi.line_total_amount
       ) order by oi.id) as items
from app.orders o
join app.order_items oi on oi.order_id = o.id
where o.customer_id = app.auth_customer_id()
group by o.id;

create or replace view api.v_inventory_reconciliation as
select i.variant_id, i.on_hand, i.reserved,
       coalesce(sum(m.on_hand_delta), 0) as movement_on_hand,
       coalesce(sum(m.reserved_delta), 0) as movement_reserved,
       i.on_hand - coalesce(sum(m.on_hand_delta), 0) as on_hand_difference,
       i.reserved - coalesce(sum(m.reserved_delta), 0) as reserved_difference
from app.inventory i
left join app.inventory_movements m on m.variant_id = i.variant_id
group by i.variant_id, i.on_hand, i.reserved;

grant select on api.v_catalog, api.v_product_fitments to anon, authenticated, service_role;
grant select on api.v_order_summary to authenticated, service_role;
grant select on api.v_inventory_reconciliation to service_role;
grant execute on function api.create_order(text, uuid, jsonb, jsonb) to anon, authenticated, service_role;
grant execute on function api.reserve_order(uuid, text) to authenticated, service_role;
grant execute on function api.release_reservation(uuid, text, boolean) to authenticated, service_role;
grant execute on function api.expire_reservations() to service_role;
grant execute on function api.confirm_order_sale(uuid, text) to service_role;
grant execute on function api.adjust_inventory(uuid, integer, text, text) to service_role;
grant execute on function api.receive_purchase(uuid, text) to service_role;
grant execute on function api.register_return(uuid, text) to service_role;

comment on schema app is 'Garage99 internal operational data; not exposed through the public Data API.';
comment on schema api is 'Garage99 safe views and transactional functions exposed to the application.';
comment on table app.inventory is 'One central stock balance per sellable SKU for the initial single-location operation.';
comment on table app.inventory_movements is 'Append-only inventory deltas; corrections use compensating movements.';
comment on table app.ml_connections is 'Mercado Libre account metadata; token_reference points to a secret store and is not a token.';

insert into app.schema_migrations(version) values ('20260906000100');

commit;
