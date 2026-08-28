-- Этап 1. Создание и заполнение БД
CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id TEXT,
    auto TEXT,
    gasoline_consumption TEXT,
    price TEXT,
    date TEXT,
    person_name TEXT,
    phone TEXT,
    discount TEXT,
    brand_origin TEXT
);
CREATE SCHEMA car_shop;

-- 1. Справочник цветов
CREATE TABLE car_shop.colors (
    color_id SERIAL PRIMARY KEY /* serial суррогатный первичный ключ с автоинкрементом для быстрой связи таблиц по целочисленному идентификатору */,
    color_name VARCHAR(50) NOT NULL UNIQUE /* varchar(50) названия цветов состоят из букв переменной длины и редко превышают 50 символов; unique защищает от дублирования названий цветов */
);

-- 2. Справочник моделей автомобилей
CREATE TABLE car_shop.models (
    model_id SERIAL PRIMARY KEY /* serial целочисленный автоинкрементный идентификатор для однозначного определения модели авто */,
    brand VARCHAR(100) NOT NULL /* varchar(100) названия брендов могут содержать как буквы, так и цифры, имеют переменную длину, ограничение в 100 символов оптимально */,
    model_name VARCHAR(150) NOT NULL /* varchar(150) коммерческие названия моделей бывают длинными и содержат спецсимволы или цифры, поэтому выбираем текстовый тип переменной длины */,
    gasoline_consumption NUMERIC(4, 1) CHECK (gasoline_consumption < 100.0) /* numeric(4, 1) точный числовой тип с фиксированной точкой; расход измеряется максимум двузначным числом и одним знаком после запятой (например, 12.5), для электромобилей поле может оставаться null */,
    brand_origin VARCHAR(100) NOT NULL /* varchar(100) текстовое поле переменной длины для хранения названия страны происхождения бренда */,
    CONSTRAINT unique_brand_model UNIQUE (brand, model_name)
);

-- 3. Таблица мост автомобиля (Связь Многие-ко-Многим)
CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY /* serial уникальный суррогатный ключ для идентификации конкретной единицы автомобиля определенной модели и цвета */,
    model_id INTEGER NOT NULL REFERENCES car_shop.models(model_id) ON DELETE CASCADE /* integer внешний ключ, соответствующий типу данных первичного ключа model_id, для связи с таблицей моделей */,
    color_id INTEGER NOT NULL REFERENCES car_shop.colors(color_id) ON DELETE CASCADE /* integer внешний ключ, соответствующий типу данных первичного ключа color_id, для связи со справочником цветов */,
    CONSTRAINT unique_car_color UNIQUE (model_id, color_id)
);

-- 4. Справочник клиентов
CREATE TABLE car_shop.customers (
    customer_id SERIAL PRIMARY KEY /* serial первичный ключ с автоинкрементом для быстрой индексации и связывания записей о клиентах */,
    person_name VARCHAR(255) NOT NULL /* varchar(255) ФИО покупателя имеет переменную длину и состоит из букв, длина до 255 символов гарантирует, что даже самые длинные составные имена не обрежутся */,
    phone VARCHAR(50) NOT NULL UNIQUE /* varchar(50) номер телефона содержит цифры и спецсимволы (+, -, скобки), поэтому используется varchar; unique добавлен, так как по ТЗ телефон является уникальным маркером клиента */
);

-- 5. Таблица продаж
CREATE TABLE car_shop.sales (
    sale_id SERIAL PRIMARY KEY /* serial первичный ключ с автоинкрементом для однозначной идентификации каждой конкретной сделки купли-продажи */,
    car_id INTEGER NOT NULL REFERENCES car_shop.cars(car_id) /* integer внешний ключ для связи транзакции продажи с конкретным автомобилем из таблицы cars */,
    customer_id INTEGER NOT NULL REFERENCES car_shop.customers(customer_id) /* integer внешний ключ для связи транзакции продажи с конкретным покупателем из таблицы customers */,
    price NUMERIC(9, 2) NOT NULL CHECK (price <= 9999999.99) /* numeric(9, 2) цена может содержать только сотые и не может быть больше семизначной суммы. У numeric повышенная точность при работе с дробными числами, поэтому при операциях с этим типом данных дробные числа не потеряются */,
    purchase_date DATE NOT NULL /* date используется специальный системный тип для хранения даты (год-месяц-день) без времени, что позволяет выполнять эффективную фильтрацию и сортировку по периодам */,
    discount NUMERIC(5, 2) NOT NULL CHECK (discount BETWEEN 0 AND 100) /* numeric(5, 2) точный числовой тип с фиксированной точкой для хранения процентов (например, 99.99%), check гарантирует валидность данных в пределах от 0 до 100% */
);
-- Заполнение таблиц
INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT trim(split_part(auto, ',', 2))
FROM raw_data.sales
WHERE auto IS NOT NULL AND auto LIKE '%,%';

INSERT INTO car_shop.models (brand, model_name, gasoline_consumption, brand_origin)
SELECT DISTINCT 
    split_part(trim(split_part(auto, ',', 1)), ' ', 1) AS brand,
    trim(substring(trim(split_part(auto, ',', 1)) from '^[^\s]+\s+(.*)$')) AS model_name,
    CASE 
        WHEN gasoline_consumption IS NULL THEN NULL
        WHEN lower(trim(gasoline_consumption)) = 'null' THEN NULL
        WHEN trim(gasoline_consumption) = '' THEN NULL 
        ELSE gasoline_consumption::NUMERIC 
    END AS gasoline_consumption,
    brand_origin
FROM raw_data.sales;

INSERT INTO car_shop.cars (model_id, color_id)
SELECT DISTINCT m.model_id, c.color_id
FROM raw_data.sales s
JOIN car_shop.models m ON m.brand = split_part(trim(split_part(s.auto, ',', 1)), ' ', 1)
    AND m.model_name = trim(substring(trim(split_part(s.auto, ',', 1)) from '^[^\s]+\s+(.*)$'))
JOIN car_shop.colors c ON c.color_name = trim(split_part(s.auto, ',', 2));

INSERT INTO car_shop.customers (person_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;

INSERT INTO car_shop.sales (car_id, customer_id, price, purchase_date, discount)
SELECT 
    car.car_id,
    cust.customer_id,
    s.price::NUMERIC,
    s.date::DATE, 
    s.discount::NUMERIC
FROM raw_data.sales s
JOIN car_shop.customers cust ON cust.phone = s.phone
JOIN car_shop.models m ON m.brand = split_part(trim(split_part(s.auto, ',', 1)), ' ', 1)
    AND m.model_name = trim(substring(trim(split_part(s.auto, ',', 1)) from '^[^\s]+\s+(.*)$'))
JOIN car_shop.colors c ON c.color_name = trim(split_part(s.auto, ',', 2))
JOIN car_shop.cars car ON car.model_id = m.model_id AND car.color_id = c.color_id;

-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.
SELECT 
    ROUND(
        (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0) / COUNT(*), 
        2
    ) AS nulls_percentage_gasoline_consumption
FROM car_shop.models;

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
SELECT 
    m.brand AS brand_name,
    EXTRACT(YEAR FROM s.purchase_date) AS year,
    ROUND(AVG(s.price), 2) AS price_avg
FROM car_shop.sales s
JOIN car_shop.cars c ON s.car_id = c.car_id
JOIN car_shop.models m ON c.model_id = m.model_id
GROUP BY m.brand, EXTRACT(YEAR FROM s.purchase_date)
ORDER BY brand_name ASC, year ASC;

---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
SELECT 
    EXTRACT(MONTH FROM purchase_date) AS month,
    EXTRACT(YEAR FROM purchase_date) AS year,
    ROUND(AVG(price), 2) AS price_avg
FROM car_shop.sales
WHERE EXTRACT(YEAR FROM purchase_date) = 2022
GROUP BY EXTRACT(MONTH FROM purchase_date), EXTRACT(YEAR FROM purchase_date)
ORDER BY month ASC;

---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.
SELECT 
    cust.person_name AS person,
    STRING_AGG(m.brand || ' ' || m.model_name, ', ') AS cars
FROM car_shop.sales s
JOIN car_shop.customers cust ON s.customer_id = cust.customer_id
JOIN car_shop.cars c ON s.car_id = c.car_id
JOIN car_shop.models m ON c.model_id = m.model_id
GROUP BY cust.customer_id, cust.person_name
ORDER BY person ASC;

---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.
SELECT 
    m.brand_origin,
    ROUND(MAX(s.price / (1 - s.discount / 100.0)), 2) AS price_max,
    ROUND(MIN(s.price / (1 - s.discount / 100.0)), 2) AS price_min
FROM car_shop.sales s
JOIN car_shop.cars c ON s.car_id = c.car_id
JOIN car_shop.models m ON c.model_id = m.model_id
GROUP BY m.brand_origin;

---- 6.
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM car_shop.customers
WHERE phone LIKE '+1%';


