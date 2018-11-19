CREATE OR REPLACE FUNCTION foo(floors_per_group int, number_of_deciles int) RETURNS TABLE (
	floor_number INT,
	employee_name VARCHAR(20),
	salary INT,
	floor_section BIGINT,
	decile INT
) AS $$
BEGIN
	RETURN QUERY 
		WITH
		floors AS (
			SELECT 
				row_number() OVER () AS row,
				generate_series AS floor_boundary
			FROM generate_series (
				(SELECT MIN(floor) FROM employees),
				(SELECT MAX(floor) FROM employees),
				floors_per_group
			)
		),
		floor_groups AS (
			SELECT
				f1.row AS floor_group,
				int4range(f1.floor_boundary, f2.floor_boundary) AS floor_range	
			FROM floors f1
			LEFT JOIN floors f2 ON f1.row + 1 = f2.row
		),
		employees_with_floor_groups AS (
			SELECT 
				emp.*,
				f.floor_group
			FROM employees emp
			INNER JOIN floor_groups f ON emp.floor <@ f.floor_range
		),
		floor_groups_with_total_salary AS (
			SELECT 
				emp.floor_group,
				SUM(emp.salary) AS total_salary
			FROM employees_with_floor_groups emp
			GROUP BY emp.floor_group
		),
		employees_with_floor_groups_and_running_total AS (
			SELECT 
				*,
				SUM(emp.salary) OVER (PARTITION BY emp.floor_group ORDER BY emp.salary DESC ROWS unbounded preceding) AS running_salary_total
			FROM employees_with_floor_groups emp
		),
		deciles AS (
			SELECT 
				generate_series AS decile
			FROM generate_series(1,number_of_deciles)
		),
		floor_groups_and_deciles AS (
			SELECT 
				f.floor_group,
				d.decile,
				int8range(
					(d.decile - 1) * (f.total_salary/number_of_deciles), 
					CASE 
						WHEN d.decile = number_of_deciles THEN d.decile * (f.total_salary/number_of_deciles) + 1 
						ELSE d.decile * (f.total_salary/number_of_deciles) 
					END
				) AS salary_range
			FROM floor_groups_with_total_salary f
			CROSS JOIN deciles d
		),
		employees_by_floor_by_deciles AS (
			SELECT 
				emps.floor,
				emps.name,
				emps.salary,
				emps.floor_group,
				decs.decile
			FROM employees_with_floor_groups_and_running_total emps
			INNER JOIN floor_groups_and_deciles decs ON emps.floor_group = decs.floor_group
				AND emps.running_salary_total <@ decs.salary_range
			ORDER BY floor_group, salary DESC
		)
		SELECT * FROM employees_by_floor_by_deciles;
END;
$$ LANGUAGE plpgsql