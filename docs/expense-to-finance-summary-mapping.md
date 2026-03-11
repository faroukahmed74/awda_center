# Expense category → Finance Summary

This table describes how each **expense type** (Income & Expenses screen) maps to the **Finance Summary** screen.

| Expense type (category) | Finance Summary       | How it's used |
|-------------------------|------------------------|----------------|
| **Salary**              | **Receptionist**       | Sum of all Salary expenses in the period → single "Receptionist" total. Default is 0 until you add Salary expenses or enter a value in the summary. |
| **Rent**                | **Rent + Guard**       | Sum of all Rent expenses in the period → single "Rent + Guard" total. Default is 0 until you add Rent expenses or enter a value in the summary. |
| **Supplies**            | **Consumables** (per doctor) | Each expense is attributed to the doctor in **Paid by doctor**; their total goes into that doctor's **Consumables** column. |
| **Other**               | **Consumables** (per doctor) | Same as Supplies: by **Paid by doctor** → that doctor's **Consumables** column. |
| **Media**               | **Media** (per doctor) | By **Paid by doctor** → that doctor's **Media** column in the summary. |

---

**Copy-friendly table (tab-separated):**

```
Expense type (category)	Finance Summary	How it's used
Salary	Receptionist	Sum of all Salary expenses in the period → single "Receptionist" total. Default 0 until you add expenses or enter a value.
Rent	Rent + Guard	Sum of all Rent expenses → single "Rent + Guard" total. Default 0 until you add expenses or enter a value.
Supplies	Consumables (per doctor)	Each expense attributed to Paid by doctor → that doctor's Consumables column.
Other	Consumables (per doctor)	Same as Supplies: by Paid by doctor → that doctor's Consumables column.
Media	Media (per doctor)	By Paid by doctor → that doctor's Media column.
```
