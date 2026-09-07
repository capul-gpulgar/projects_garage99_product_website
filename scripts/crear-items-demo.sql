-- Garage99 demo data: catalog, compatibility, prices and auditable stock.
-- Run in Supabase SQL Editor as the database owner.
-- All identifiers use DEMO slugs/UUIDs and can be rerun safely.

begin;

insert into app.categories (id, name, slug) values
 ('a1000000-0000-0000-0000-000000000001','Frenos demo','demo-frenos'),
 ('a1000000-0000-0000-0000-000000000002','Transmision demo','demo-transmision')
on conflict (id) do update set name=excluded.name, slug=excluded.slug, active=true;

insert into app.product_brands (id,name,slug)
values ('a2000000-0000-0000-0000-000000000001','Garage99 Demo Items','garage99-demo-items')
on conflict (id) do update set name=excluded.name, slug=excluded.slug, active=true;

insert into app.products (id,category_id,brand_id,name,slug,description,status) values
 ('a3000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','Pastillas de freno delanteras demo','pastillas-freno-demo','Repuesto ficticio para pruebas','published'),
 ('a3000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','Kit de transmision demo','kit-transmision-demo','Kit cerrado ficticio con stock propio','published')
on conflict (id) do update set category_id=excluded.category_id, brand_id=excluded.brand_id, name=excluded.name, slug=excluded.slug, description=excluded.description, status=excluded.status, updated_at=now();

insert into app.product_variants (id,product_id,sku,name,cost_amount,currency_code) values
 ('a4000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','G99-DEMO-BRK-001','Pastillas delanteras',7000,'CLP'),
 ('a4000000-0000-0000-0000-000000000002','a3000000-0000-0000-0000-000000000002','G99-DEMO-CHAIN-001','Kit cadena cerrado',25000,'CLP')
on conflict (id) do update set product_id=excluded.product_id, sku=excluded.sku, name=excluded.name, cost_amount=excluded.cost_amount, currency_code=excluded.currency_code, active=true, updated_at=now();

insert into app.motorcycle_makes (id,name,slug) values
 ('a5000000-0000-0000-0000-000000000001','Honda Demo Items','honda-demo-items'),
 ('a5000000-0000-0000-0000-000000000002','Yamaha Demo Items','yamaha-demo-items')
on conflict (id) do update set name=excluded.name, slug=excluded.slug, active=true;

insert into app.motorcycle_models (id,make_id,name,slug) values
 ('a6000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','CG 150 demo','cg-150-demo'),
 ('a6000000-0000-0000-0000-000000000002','a5000000-0000-0000-0000-000000000002','FZ 2.0 demo','fz-2-demo')
on conflict (id) do update set make_id=excluded.make_id, name=excluded.name, slug=excluded.slug, active=true;

insert into app.motorcycle_versions (id,model_id,name,engine_code,year_from,year_to) values
 ('a7000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001','CG 150 2010-2016','CG150-DEMO',2010,2016),
 ('a7000000-0000-0000-0000-000000000002','a6000000-0000-0000-0000-000000000002','FZ 2.0 2015-2020','FZ2-DEMO',2015,2020)
on conflict (id) do update set model_id=excluded.model_id, name=excluded.name, engine_code=excluded.engine_code, year_from=excluded.year_from, year_to=excluded.year_to, active=true, updated_at=now();

insert into app.product_fitments (id,variant_id,motorcycle_version_id,year_from,year_to,notes,source_type,source_reference,verified_at) values
 ('a7100000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000001',2010,2016,'Compatibilidad ficticia','verified_manual','demo-script',now()),
 ('a7100000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000002',2015,2020,'Segunda compatibilidad ficticia','verified_manual','demo-script',now()),
 ('a7100000-0000-0000-0000-000000000003','a4000000-0000-0000-0000-000000000002','a7000000-0000-0000-0000-000000000001',2010,2016,'Kit cerrado ficticio','verified_manual','demo-script',now())
on conflict (id) do update set year_from=excluded.year_from, year_to=excluded.year_to, notes=excluded.notes, source_type=excluded.source_type, source_reference=excluded.source_reference, verified_at=excluded.verified_at;

insert into app.part_references (id,variant_id,reference_type,reference_brand,reference_code,notes)
values ('a7200000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','manufacturer','Garage99 Demo','OEM-DEMO-001','Referencia ficticia')
on conflict (id) do update set reference_code=excluded.reference_code, notes=excluded.notes;

insert into app.sales_channels (id,code,name,safety_stock_default)
values ('a8000000-0000-0000-0000-000000000001','web','Web',1)
on conflict (code) do update set active=true;

insert into app.variant_prices (id,variant_id,channel_id,currency_code,unit_price_amount,valid_from)
select 'a9000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',id,'CLP',12000,now() from app.sales_channels where code='web'
on conflict (id) do update set unit_price_amount=excluded.unit_price_amount, active=true;
insert into app.variant_prices (id,variant_id,channel_id,currency_code,unit_price_amount,valid_from)
select 'a9000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-000000000002',id,'CLP',45000,now() from app.sales_channels where code='web'
on conflict (id) do update set unit_price_amount=excluded.unit_price_amount, active=true;

-- The product_variants trigger creates these rows; this keeps the script repeatable.
insert into app.inventory (variant_id,on_hand,reserved,safety_stock,reorder_point) values
 ('a4000000-0000-0000-0000-000000000001',0,0,1,2),
 ('a4000000-0000-0000-0000-000000000002',0,0,1,1)
on conflict (variant_id) do nothing;

-- Initial balances are represented by operations plus movements.
do $$
begin
  if not exists (select 1 from app.inventory_movements where id='ab000000-0000-0000-0000-000000000001') then
    update app.inventory set on_hand=5, safety_stock=1, reorder_point=2, updated_at=now() where variant_id='a4000000-0000-0000-0000-000000000001';
    insert into app.inventory_operations (id,idempotency_key,operation_type,variant_id,quantity,source_type,source_id,status,result,completed_at)
    values ('aa000000-0000-0000-0000-000000000001','demo-initial-brk-001','initial_balance','a4000000-0000-0000-0000-000000000001',5,'manual','a4000000-0000-0000-0000-000000000001','succeeded','{"source":"demo-script"}',now()) on conflict (idempotency_key) do nothing;
    insert into app.inventory_movements (id,operation_id,variant_id,on_hand_delta,reason,reference_type,reference_id)
    values ('ab000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',5,'demo initial balance','manual','a4000000-0000-0000-0000-000000000001');
  end if;
end $$;

do $$
begin
  if not exists (select 1 from app.inventory_movements where id='ab000000-0000-0000-0000-000000000002') then
    update app.inventory set on_hand=3, safety_stock=1, reorder_point=1, updated_at=now() where variant_id='a4000000-0000-0000-0000-000000000002';
    insert into app.inventory_operations (id,idempotency_key,operation_type,variant_id,quantity,source_type,source_id,status,result,completed_at)
    values ('aa000000-0000-0000-0000-000000000002','demo-initial-chain-001','initial_balance','a4000000-0000-0000-0000-000000000002',3,'manual','a4000000-0000-0000-0000-000000000002','succeeded','{"source":"demo-script"}',now()) on conflict (idempotency_key) do nothing;
    insert into app.inventory_movements (id,operation_id,variant_id,on_hand_delta,reason,reference_type,reference_id)
    values ('ab000000-0000-0000-0000-000000000002','aa000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-000000000002',3,'demo initial balance','manual','a4000000-0000-0000-0000-000000000002');
  end if;
end $$;

commit;

select * from api.v_catalog where sku like 'G99-DEMO-%' order by sku;
select * from api.v_product_fitments where sku like 'G99-DEMO-%' order by sku, motorcycle_make;
select variant_id,on_hand,reserved,available,safety_stock,reorder_point from app.inventory where variant_id in ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000002') order by variant_id;
