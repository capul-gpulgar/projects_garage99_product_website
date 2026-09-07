-- Validate the Garage99 business schema after applying the two 20260906 migrations.
-- All business writes in this file run inside a transaction that is rolled back.
begin;

do $$
declare
    expected_tables text[] := array[
        'categories', 'product_brands', 'products', 'product_variants', 'product_images',
        'motorcycle_makes', 'motorcycle_models', 'motorcycle_versions', 'product_fitments',
        'part_references', 'suppliers', 'supplier_products', 'purchase_orders',
        'purchase_order_items', 'goods_receipts', 'goods_receipt_items', 'customers',
        'sales_channels', 'variant_prices', 'orders', 'order_items', 'inventory',
        'inventory_operations', 'inventory_movements', 'inventory_reservations',
        'payment_attempts', 'refunds', 'shipments', 'returns', 'return_items',
        'warranty_claims', 'ml_connections', 'ml_listings', 'integration_events',
        'integration_jobs', 'integration_logs', 'staff_roles', 'audit_events'
    ];
    table_name text;
begin
    foreach table_name in array expected_tables loop
        if to_regclass('app.' || table_name) is null then
            raise exception 'Missing app table: %', table_name;
        end if;
        if not (select relrowsecurity from pg_class where oid = ('app.' || table_name)::regclass) then
            raise exception 'RLS is disabled on app.%', table_name;
        end if;
    end loop;
    if to_regclass('app.schema_migrations') is null then
        raise exception 'Migration tracking table is missing';
    end if;
    if to_regclass('api.v_catalog') is null or to_regclass('api.v_product_fitments') is null
       or to_regclass('api.v_order_summary') is null then
        raise exception 'Expected API views are missing';
    end if;
end;
$$;

do $$
declare
    v_order_id uuid := '20000000-0000-0000-0000-000000000001';
    v_order_item_id uuid := '20000000-0000-0000-0000-000000000002';
    v_variant_id uuid := '10000000-0000-0000-0000-000000000020';
    v_channel_id uuid;
    v_on_hand integer;
    v_reserved integer;
    v_result jsonb;
begin
    select id into v_channel_id from app.sales_channels where code = 'web';
    if v_channel_id is null then raise exception 'Demo web channel is missing'; end if;
    insert into app.orders(id, order_number, channel_id, status, payment_status, fulfillment_status, currency_code)
    values (v_order_id, 'G99-VALIDATION', v_channel_id, 'pending', 'pending', 'pending', 'CLP');
    insert into app.order_items(id, order_id, variant_id, sku_snapshot, name_snapshot, quantity, unit_price_amount, line_total_amount)
    values (v_order_item_id, v_order_id, v_variant_id, 'DEMO-BRK-001', 'Validation brake pads', 2, 12000, 24000);

    v_result := api.reserve_order(v_order_id, 'validation-reserve-001');
    select on_hand, reserved into v_on_hand, v_reserved from app.inventory where variant_id = v_variant_id;
    if v_on_hand <> 10 or v_reserved <> 2 or v_result->>'status' <> 'reserved' then
        raise exception 'Reservation result is inconsistent: %, %, %', v_on_hand, v_reserved, v_result;
    end if;

    v_result := api.reserve_order(v_order_id, 'validation-reserve-001');
    select reserved into v_reserved from app.inventory where variant_id = v_variant_id;
    if v_reserved <> 2 then raise exception 'Reservation idempotency failed'; end if;

    v_result := api.confirm_order_sale(v_order_id, 'validation-sale-001');
    select on_hand, reserved into v_on_hand, v_reserved from app.inventory where variant_id = v_variant_id;
    if v_on_hand <> 8 or v_reserved <> 0 or v_result->>'status' <> 'paid' then
        raise exception 'Sale result is inconsistent: %, %, %', v_on_hand, v_reserved, v_result;
    end if;

    begin
        insert into app.orders(id, order_number, channel_id, status, payment_status, fulfillment_status, currency_code)
        values ('20000000-0000-0000-0000-000000000003', 'G99-VALIDATION-FAIL', v_channel_id, 'pending', 'pending', 'pending', 'CLP');
        insert into app.order_items(order_id, variant_id, sku_snapshot, name_snapshot, quantity, unit_price_amount, line_total_amount)
        values ('20000000-0000-0000-0000-000000000003', v_variant_id, 'DEMO-BRK-001', 'Validation brake pads', 999, 12000, 11988000);
        perform api.reserve_order('20000000-0000-0000-0000-000000000003', 'validation-insufficient-001');
        raise exception 'Insufficient reservation unexpectedly succeeded';
    exception when others then
        if sqlstate not in ('P0001', '55000') then raise; end if;
    end;
end;
$$;

do $$
begin
    if has_table_privilege('anon', 'app.inventory', 'SELECT') then
        raise exception 'anon has direct inventory access';
    end if;
    if has_table_privilege('authenticated', 'app.inventory', 'INSERT') then
        raise exception 'authenticated has direct inventory write access';
    end if;
    if not has_schema_privilege('anon', 'api', 'USAGE') then
        raise exception 'anon cannot use API schema';
    end if;
    if not has_table_privilege('anon', 'api.v_catalog', 'SELECT') then
        raise exception 'anon cannot read catalog view';
    end if;
end;
$$;

select 'PASS: Garage99 schema, seed, RLS, reservation, idempotency and sale checks' as result,
       (select count(*) from app.schema_migrations where version in ('20260906000100', '20260906000200')) as applied_business_migrations,
       (select count(*) from app.product_variants) as seeded_variants,
       (select count(*) from app.inventory) as inventory_rows,
       now() as checked_at;

rollback;
