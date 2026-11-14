-- Records the verdict of the run: a configuration set forces it to count as failed whatever its
-- actual result.  The key sits at the top of the job-type object, beside [force], because
-- [run_params] is a string map and cannot carry a boolean.
update jobs set params = jsonb_set(params, '{force_fail}', to_jsonb($force_fail::boolean), true)
where id = $job
