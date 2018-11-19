-- Given the employees table, rank each employee by salary decile in each floor group

CREATE OR REPLACE FUNCTION foo(floors_per_group int, number_of_deciles int) RETURNS TABLE (
	floor_number INT,
	employee_name VARCHAR(20),
	salary INT,
	floor_section BIGINT,
	decile INT
) AS $$
BEGIN
	-- Put your function here
END;
$$ LANGUAGE plpgsql;

SELECT foo(4,3) -- this should return the table in Output.csv