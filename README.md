# Car Rental Management System
### C++ + MySQL  |  Full Project

---

## Project Structure

```
car_rental_system.cpp    ← full C++ source (all logic + DB calls)
car_rental_schema.sql    ← standalone SQL schema with seed data & views
README.md                ← this file
```

---

## Database Tables

| Table       | Purpose                                              |
|-------------|------------------------------------------------------|
| `Branches`  | Your shop locations (city, address, phone)           |
| `Cars`      | Fleet catalogue; `is_available` flips on rent/return |
| `Users`     | Registered customers (name, email, driving licence)  |
| `Rentals`   | Core transaction; stores base charge + fine          |
| `Payments`  | Payment records linked to each rental                |

### Key Columns in `Rentals`
| Column           | Meaning                                       |
|------------------|-----------------------------------------------|
| `rent_date`      | When the car was handed over                  |
| `expected_return`| Agreed deadline                               |
| `actual_return`  | NULL while active; filled on return           |
| `fine_amount`    | 20 % of daily rate × overdue days             |
| `total_charge`   | base_charge + fine_amount                     |
| `status`         | `Active` → `Overdue` → `Returned`             |

---

## Fine Formula

```
overdue_days = CEIL( (actual_return - expected_return) / 86400 )
fine         = overdue_days × daily_rate × 0.20
total_charge = (actual_days × daily_rate) + fine
```

---

## Database Setup
```bash
mysql -u root -p < car_rental_schema.sql
```

---

## Configuration

```cpp
const char* DB_HOST = "localhost";
const char* DB_USER = "root";
const char* DB_PASS = "root1234";
const char* DB_NAME = "CarRentalDB";
```

---

## Features

| Module          | What you can do                                           |
|-----------------|-----------------------------------------------------------|
| **Branches**    | List all branches, add new branch                        |
| **Cars**        | List all / available cars, add car to a branch           |
| **Customers**   | Register new customer, list all customers                |
| **Rent a Car**  | Pick customer → pick car → set days → creates rental     |
| **Return a Car**| Auto-calculates overdue days & fine, records payment     |
| **Overdue Check**| Flags late rentals, shows estimated fine per rental     |
| **Reports**     | Revenue by branch, full rental history (last 50)         |

---

## SQL Views (ready to query)

```sql
SELECT * FROM v_active_rentals;    -- all currently rented cars
SELECT * FROM v_overdue_rentals;   -- late returns with estimated fine
SELECT * FROM v_branch_revenue;    -- revenue summary per branch
CALL mark_overdue();               -- batch-flag overdue rentals (run via cron)
```

---
**Cars:** 7 sample cars across categories (Economy → Luxury)

