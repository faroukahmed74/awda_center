# Salary System – Options

Your app already has **Income & Expenses** with:
- **Income:** free-text source, amount, date → `income_records`
- **Expenses:** categories including **Salary** → `expense_records`  
  Current categories: `Salary`, Rent, Utilities, Supplies, Equipment, Other.

**Workflow:** **Admin** (or secretary, per your permissions) enters salary for all center employees. Employees are **doctors, secretary, and trainee** — no new roles; the dropdown uses these existing roles only.

So you can already record “salary paid” as an expense. Below are two ways to make it a real “salary system.”

---

## Option A – Integrate into Income & Expenses (implemented)

**Idea:** Keep using the same Income & Expenses screen and reports; add **employee link** when the expense category is **Salary**, so you know who was paid and can report by person.

**Changes (done):**
1. **Expense model** – Optional `recipientUserId` and `recipientName` on `ExpenseRecordModel`.
2. **Add Expense dialog** – When category is **Salary**, a dropdown lets admin select the **employee** (doctors, secretary, trainee only). Admin enters the salary for each; recipient is saved on the expense.
3. **Income & Expenses screen** – Salary expenses show “Salary – [Employee name]” when an employee is set.
4. **Reports** – Same display in the Income/Expenses report; you can filter or total by category = Salary and by employee.

**Pros:** Small change, reuses existing screens and reports, no new collections.  
**Cons:** No dedicated “payroll” workflow (e.g. pending vs paid); that’s Option B.

---

## Option B – Dedicated Salary / Payroll module

**Idea:** A separate “Salaries” or “Payroll” feature: define who gets paid how much for which period, track status, and optionally sync with expenses when paid.

**Possible design:**
- **New Firestore collection** e.g. `salary_records` (or `payroll`):
  - `employeeId` (user id), `amount`, `currency`, `periodStart`, `periodEnd`, `status` (e.g. pending / paid), `paidAt`, `expenseRecordId` (optional, link to `expense_records` when paid), `notes`, `createdBy`, `createdAt`.
- **New screen “Salaries” (or “Payroll”):**
  - List salary records (filter by period, employee, status).
  - Add new: select employee, amount, period (e.g. month), optional notes → creates record with status “pending”.
  - “Mark as paid”: set status = paid, set paidAt, and optionally create an expense in `expense_records` (category Salary, recipientUserId = employeeId) and save its id in `expenseRecordId`.
- **Reports:** New tab or section “Salary report”: total salary per period, per employee, pending vs paid. Optionally reuse the same totals in the existing Income & Expenses report by including salary expenses (with or without linking to salary_records).

**Pros:** Clear payroll workflow, pending/paid, period-based, and optional one-click “pay” that creates the expense.  
**Cons:** More code and a new collection; only worth it if you need proper payroll tracking.

---

## Recommendation

- **Start with Option A:** Add optional **employee** to Salary expenses (recipient user + name). You get “salary by person” in the same Income & Expenses flow and reports with minimal change.
- **Add Option B later** if you need: multiple payments per period, “pending salary” list, or a dedicated payroll screen and reports.

If you tell me which option you want (A only, B only, or A now and B later), I can outline exact code changes (files and fields) or implement Option A in the repo step by step.
