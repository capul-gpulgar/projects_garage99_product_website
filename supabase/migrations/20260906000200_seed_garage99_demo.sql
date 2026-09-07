begin;

-- Repeatable fictitious seed. It is intentionally small and contains no customer,
-- payment, supplier credential or marketplace token data.
insert into app.categories(id, name, slug)
values ('10000000-0000-0000-0000-000000000001', 'Frenos', 'frenos')
on conflict (id) do update set name = excluded.name, slug = excluded.slug, active = true;

insert into app.product_brands(id, name, slug)
values ('10000000-0000-0000-0000-000000000002', 'Garage99 Demo', 'garage99-demo')
on conflict (id) do update set name = excluded.name, slug = excluded.slug, active = true;

insert into app.products(id, category_id, brand_id, name, slug, description, status)
values
    ('10000000-0000-0000-0000-000000000010', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Pastillas de freno delanteras demo', 'pastillas-freno-delanteras-demo', 'Referencia ficticia para validar catálogo y compatibilidad.', 'published'),
    ('10000000-0000-0000-0000-000000000011', '10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Kit de cadena cerrado demo', 'kit-cadena-cerrado-demo', 'Kit ficticio vendido como un SKU independiente.', 'published')
on conflict (id) do update set name = excluded.name, slug = excluded.slug, description = excluded.description, status = excluded.status;

insert into app.product_variants(id, product_id, sku, name, cost_amount, currency_code)
values
    ('10000000-0000-0000-0000-000000000020', '10000000-0000-0000-0000-000000000010', 'DEMO-BRK-001', 'Pastillas delanteras demo', 5000, 'CLP'),
    ('10000000-0000-0000-0000-000000000021', '10000000-0000-0000-0000-000000000011', 'DEMO-KIT-001', 'Kit de cadena cerrado demo', 35000, 'CLP')
on conflict (id) do update set name = excluded.name, cost_amount = excluded.cost_amount, active = true;

insert into app.motorcycle_makes(id, name, slug)
values ('10000000-0000-0000-0000-000000000030', 'Yamaha Demo', 'yamaha-demo')
on conflict (id) do update set name = excluded.name, slug = excluded.slug, active = true;

insert into app.motorcycle_models(id, make_id, name, slug)
values ('10000000-0000-0000-0000-000000000031', '10000000-0000-0000-0000-000000000030', 'FZ Demo', 'fz-demo')
on conflict (id) do update set name = excluded.name, slug = excluded.slug, active = true;

insert into app.motorcycle_versions(id, model_id, name, engine_code, displacement_cc, year_from, year_to)
values ('10000000-0000-0000-0000-000000000032', '10000000-0000-0000-0000-000000000031', 'FZ 150 Demo', 'DEMO-150', 150, 2015, 2020)
on conflict (id) do update set name = excluded.name, engine_code = excluded.engine_code, active = true;

insert into app.product_fitments(id, variant_id, motorcycle_version_id, source_type, source_reference, verified_at)
values ('10000000-0000-0000-0000-000000000033', '10000000-0000-0000-0000-000000000020', '10000000-0000-0000-0000-000000000032', 'verified_manual', 'Garage99 demo fixture', now())
on conflict (id) do update set source_type = excluded.source_type, source_reference = excluded.source_reference, verified_at = excluded.verified_at;

insert into app.sales_channels(id, code, name, safety_stock_default)
values
    ('10000000-0000-0000-0000-000000000040', 'web', 'Tienda web', 1),
    ('10000000-0000-0000-0000-000000000041', 'pos', 'Mostrador', 0),
    ('10000000-0000-0000-0000-000000000042', 'mercadolibre', 'Mercado Libre', 1)
on conflict (code) do update set name = excluded.name, safety_stock_default = excluded.safety_stock_default, active = true;

insert into app.variant_prices(id, variant_id, channel_id, unit_price_amount, currency_code, valid_from)
values
    ('10000000-0000-0000-0000-000000000050', '10000000-0000-0000-0000-000000000020', '10000000-0000-0000-0000-000000000040', 12000, 'CLP', '2026-01-01T00:00:00Z'),
    ('10000000-0000-0000-0000-000000000051', '10000000-0000-0000-0000-000000000021', '10000000-0000-0000-0000-000000000040', 75000, 'CLP', '2026-01-01T00:00:00Z'),
    ('10000000-0000-0000-0000-000000000052', '10000000-0000-0000-0000-000000000020', '10000000-0000-0000-0000-000000000041', 11500, 'CLP', '2026-01-01T00:00:00Z'),
    ('10000000-0000-0000-0000-000000000053', '10000000-0000-0000-0000-000000000021', '10000000-0000-0000-0000-000000000041', 72000, 'CLP', '2026-01-01T00:00:00Z'),
    ('10000000-0000-0000-0000-000000000054', '10000000-0000-0000-0000-000000000020', '10000000-0000-0000-0000-000000000042', 12500, 'CLP', '2026-01-01T00:00:00Z'),
    ('10000000-0000-0000-0000-000000000055', '10000000-0000-0000-0000-000000000021', '10000000-0000-0000-0000-000000000042', 78000, 'CLP', '2026-01-01T00:00:00Z')
on conflict (id) do update set unit_price_amount = excluded.unit_price_amount, active = true;

do $$
declare
    v_variant uuid;
    v_balance integer;
    v_key text;
    v_operation uuid;
    v_seed record;
begin
    for v_seed in
        select * from (values
            ('10000000-0000-0000-0000-000000000020'::uuid, 10, 'demo-initial-balance-brk'),
            ('10000000-0000-0000-0000-000000000021'::uuid, 2, 'demo-initial-balance-kit')
        ) as seeds(variant_id, balance, operation_key)
    loop
        v_variant := v_seed.variant_id;
        v_balance := v_seed.balance;
        v_key := v_seed.operation_key;
        if not exists (select 1 from app.inventory_movements m where m.reference_type = 'seed' and m.reference_id = v_variant::uuid) then
            update app.inventory set on_hand = v_balance, safety_stock = 1 where variant_id = v_variant;
            insert into app.inventory_operations(idempotency_key, operation_type, variant_id, quantity, source_type, source_id, status, result, completed_at)
            values (v_key, 'initial_balance', v_variant, v_balance, 'seed', v_variant, 'succeeded', jsonb_build_object('seed', true), now())
            returning id into v_operation;
            insert into app.inventory_movements(operation_id, variant_id, on_hand_delta, reason, reference_type, reference_id)
            values (v_operation, v_variant, v_balance, 'demo seed initial balance', 'seed', v_variant);
        end if;
    end loop;
end;
$$;

insert into app.schema_migrations(version) values ('20260906000200')
on conflict (version) do nothing;

commit;
