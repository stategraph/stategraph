(* Helper to run roundtrip test on the entire AST *)
let roundtrip_test ?(schema = Hcl_parser_value_json.Schema.tf) ~name hcl_string =
  Oth.test ~name (fun _ ->
      let ast = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string hcl_string) in
      let json = Hcl_parser_value_json.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp
          ~pp:Hcl_parser_value_json.pp_err
          (Hcl_parser_value_json.to_ast ~schema json)
      in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast ast roundtripped;
      ())

let string_roundtrip_test ?(schema = Hcl_parser_value_json.Schema.tf) ~name hcl_string =
  Oth.test ~name (fun _ ->
      let ast = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string hcl_string) in
      let json = Hcl_parser_value_json.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp
          ~pp:Hcl_parser_value_json.pp_err
          (Hcl_parser_value_json.to_ast ~schema json)
      in
      let result = Hcl_ast.To_string.ast roundtripped in
      Oth.Assert.Eq.string ~expected:hcl_string ~actual:result;
      ())

let test_string_roundtrip_terraform_provider =
  string_roundtrip_test
    ~name:"string_roundtrip_terraform_provider"
    {|terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}|}

let test_string_roundtrip_data_source_with_backend =
  string_roundtrip_test
    ~name:"string_roundtrip_terraform_provider"
    {|data "terraform_remote_state" "network" {
  backend = "http"
  config  = {
    address = "https://stategraph/f3784b78-a077-4a1f-ad12-910a37df78b6"
  }
}|}

(* Nested template inside a function-call argument inside an outer interpolation.
   Regression: the JSON roundtrip went
     Template [ Interp(file("${path.module}/data.txt")); ... ]
   → "${file("${path.module}/data.txt")}-..."  (pp_expr → template_to_string)
   → parse_template_string (no transform)
   → Template [ Interp(Fun_call("file", [String "${path.module}/data.txt"])); ... ]
   and the printer's escape_hcl_string then mangled the inner ${path.module} to $${path.module},
   which made tofu treat it as a literal string and fail with "no file exists at
   ${path.module}/data.txt". *)
let test_string_roundtrip_nested_file_in_interpolation =
  string_roundtrip_test
    ~name:"string_roundtrip_nested_file_in_interpolation"
    {|resource "terraform_data" "dup" {
  input = "${file("data.txt")}-${file("data.txt")}"
}|}

(* Same failure mode as above with a mix of file() and filebase64() — both live inside an outer
   Template and their rewritten first-argument Templates must not be double-escaped. *)
let test_string_roundtrip_nested_filebase64_in_interpolation =
  string_roundtrip_test
    ~name:"string_roundtrip_nested_filebase64_in_interpolation"
    {|resource "terraform_data" "mixed" {
  input = "${file("${path.module}/data.txt")}-${filebase64("${path.module}/data.txt")}"
}|}

(* Test: Simple attribute *)
let test_simple_attribute = roundtrip_test ~name:"simple_attribute" {|foo = "bar"|}

(* Test: Attribute with int *)
let test_attribute_int = roundtrip_test ~name:"attribute_int" {|count = 42|}

(* Test: Attribute with bool *)
let test_attribute_bool = roundtrip_test ~name:"attribute_bool" {|enabled = true|}

(* Test: Attribute with null *)
let test_attribute_null = roundtrip_test ~name:"attribute_null" {|value = null|}

(* Test: Attribute with float *)
let test_attribute_float = roundtrip_test ~name:"attribute_float" {|ratio = 3.14|}

(* Test: Attribute with tuple *)
let test_attribute_tuple = roundtrip_test ~name:"attribute_tuple" {|items = ["a", "b", "c"]|}

(* Test: Attribute with object *)
let test_attribute_object = roundtrip_test ~name:"attribute_object" {|config = {
  key = "value"
}|}

(* Regression: an object-valued attribute whose heredoc body mixes a [${...}]
   interpolation, a [$${...}] literal-escape, embedded quotes, and backslash
   sequences (a cloud-build script) must survive the JSON round-trip as an object.
   Previously [json_to_expr] gated unwrapping on a template re-parse that desyncs on
   this content, collapsing the whole value to a literal ["$${ {...} }"] string and
   producing tofu "object required, but have string". *)
let test_attribute_object_heredoc_build =
  roundtrip_test
    ~name:"attribute_object_heredoc_build"
    {|build = {
  steps = [{
    name   = "gcr.io/cloud-builders/docker"
    env    = ["COMMIT_SHA=$COMMIT_SHA"]
    script = <<EOT
#!/usr/bin/env bash
version=($(sed -En 's/^version = "([0-9]+)\.([0-9]+)\.([0-9]+).+/\1,\2,\3/p' pyproject.toml))
echo "Got version: $${version[@]}"
docker build --tag=${var.image_uri}:V$${version[0]}.$${version[1]} .
EOT
  }]
}|}

(* Test: Block with no labels (e.g., locals) *)
let test_block_no_labels = roundtrip_test ~name:"block_no_labels" {|locals {
  foo = "bar"
}|}

(* Test: Block with one label (e.g., variable) *)
let test_block_one_label =
  roundtrip_test ~name:"block_one_label" {|variable "name" {
  default = "value"
}|}

(* Test: Block with two labels (e.g., resource) *)
let test_block_two_labels =
  roundtrip_test
    ~name:"block_two_labels"
    {|resource "aws_s3_bucket" "example" {
  bucket = "test"
}|}

(* Test: Multiple blocks with same type *)
let test_multiple_blocks_same_type =
  roundtrip_test
    ~name:"multiple_blocks_same_type"
    {|resource "aws_s3_bucket" "first" {
  bucket = "bucket1"
}
resource "aws_s3_bucket" "second" {
  bucket = "bucket2"
}|}

(* Test: Complex expression - variable reference *)
let test_expr_var_ref = roundtrip_test ~name:"expr_var_ref" {|region = var.region|}

(* Test: Complex expression - function call *)
let test_expr_function_call =
  roundtrip_test ~name:"expr_function_call" {|upper_name = upper(var.name)|}

(* Test: Complex expression - conditional *)
let test_expr_conditional =
  roundtrip_test ~name:"expr_conditional" {|status = var.enabled ? "yes" : "no"|}

(* Test: Complex expression - binary operation *)
let test_expr_binary_op = roundtrip_test ~name:"expr_binary_op" {|total = var.count + 10|}

(* Test: Complex expression - for tuple *)
let test_expr_for_tuple =
  roundtrip_test ~name:"expr_for_tuple" {|names = [for x in var.items : upper(x)]|}

(* Test: Complex expression - for object *)
let test_expr_for_object =
  roundtrip_test ~name:"expr_for_object" {|mapping = {
  for k, v in var.items :
  k => upper(v)
}|}

(* Test: Complex expression - index *)
let test_expr_index = roundtrip_test ~name:"expr_index" {|first = var.items[0]|}

(* Test: Complex expression - attribute access *)
let test_expr_attr_access =
  roundtrip_test ~name:"expr_attr_access" {|name = aws_instance.example.id|}

(* Schema extended with provider-specific block types for tests that need them *)
let schema_with_provider_blocks =
  let module S = Hcl_parser_value_json.Schema in
  S.union S.tf (S.make [ ([ "resource"; "ingress" ], 0); ([ "resource"; "tags" ], 0) ])

(* Test: Nested blocks *)
let test_nested_blocks =
  roundtrip_test
    ~schema:schema_with_provider_blocks
    ~name:"nested_blocks"
    {|resource "aws_security_group" "example" {
  name = "test"
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
}|}

(* Test: Multiple nested blocks *)
let test_multiple_nested_blocks =
  roundtrip_test
    ~schema:schema_with_provider_blocks
    ~name:"multiple_nested_blocks"
    {|resource "aws_security_group" "example" {
  name = "test"
  ingress {
    from_port = 80
  }
  ingress {
    from_port = 443
  }
}|}

(* Test: Mixed attributes and blocks *)
let test_mixed_content =
  roundtrip_test
    ~schema:schema_with_provider_blocks
    ~name:"mixed_content"
    {|resource "aws_instance" "example" {
  ami = "ami-123"
  instance_type = "t2.micro"
  tags {
    name = "example"
  }
}|}

(* === Edge cases that could break roundtrip encoding === *)

(* Test: String containing dollar sign but not interpolation *)
let test_string_with_dollar = roundtrip_test ~name:"string_with_dollar" {|price = "$100"|}

(* NOTE: Incomplete interpolation "${incomplete" causes parser issues - not tested *)

(* Regression: a literal string written with the $${ / %%{ escape must survive the JSON
   roundtrip as a literal, not be reinterpreted as an interpolation/directive. Previously
   the escape was dropped on encode ("$${foo}" -> "${foo}") and decoded back as a live
   interpolation. *)
let test_string_roundtrip_escaped_interpolation =
  string_roundtrip_test ~name:"string_roundtrip_escaped_interpolation" {|literal = "$${foo}"|}

let test_string_roundtrip_escaped_interpolation_with_text =
  string_roundtrip_test
    ~name:"string_roundtrip_escaped_interpolation_with_text"
    {|literal = "prefix-$${foo}-suffix"|}

let test_string_roundtrip_escaped_directive =
  string_roundtrip_test ~name:"string_roundtrip_escaped_directive" {|literal = "%%{ if true }"|}

(* A literal escape adjacent to a real interpolation: the $${literal} stays literal text
   while ${var.x} stays a live interpolation. *)
let test_string_roundtrip_mixed_escape_and_interpolation =
  string_roundtrip_test
    ~name:"string_roundtrip_mixed_escape_and_interpolation"
    {|literal = "$${literal}-${var.x}"|}

(* Test: Empty string *)
let test_empty_string = roundtrip_test ~name:"empty_string" {|empty = ""|}

(* Test: String with newlines *)
let test_string_with_newlines =
  roundtrip_test ~name:"string_with_newlines" {|multiline = "line1\nline2\nline3"|}

(* Test: String with escaped quotes *)
let test_string_with_quotes = roundtrip_test ~name:"string_with_quotes" {|quoted = "say \"hello\""|}

(* Test: String with backslashes *)
let test_string_with_backslashes =
  roundtrip_test ~name:"string_with_backslashes" {|path = "C:\\Users\\test"|}

(* Test: String with tabs *)
let test_string_with_tabs = roundtrip_test ~name:"string_with_tabs" {|tabbed = "col1\tcol2"|}

(* Test: Tuple containing mixed simple and complex expressions *)
let test_tuple_mixed =
  roundtrip_test ~name:"tuple_mixed" {|mixed = ["simple", var.complex, 42, true]|}

(* Test: Deeply nested tuple *)
let test_nested_tuple = roundtrip_test ~name:"nested_tuple" {|nested = [["a", "b"], ["c", "d"]]|}

(* Test: Object with nested object value *)
let test_nested_object =
  roundtrip_test ~name:"nested_object" {|outer = {
  inner = {
    deep = "value"
  }
}|}

(* Test: Expression containing string with interpolation *)
let test_expr_with_interpolated_string =
  roundtrip_test ~name:"expr_with_interpolated_string" {|greeting = "Hello, ${var.name}!"|}

(* Test: String with multiple interpolations *)
let test_multiple_interpolations =
  roundtrip_test ~name:"multiple_interpolations" {|combined = "${var.first} and ${var.second}"|}

(* Test: Splat expression *)
let test_splat_expr = roundtrip_test ~name:"splat_expr" {|all_ids = aws_instance.example[*].id|}

(* Test: Negative number *)
let test_negative_number = roundtrip_test ~name:"negative_number" {|offset = -10|}

(* Test: Unary not *)
let test_unary_not = roundtrip_test ~name:"unary_not" {|disabled = !var.enabled|}

(* Test: Logical operators *)
let test_logical_ops = roundtrip_test ~name:"logical_ops" {|condition = var.a && var.b || var.c|}

(* Test: Comparison operators *)
let test_comparison_ops =
  roundtrip_test ~name:"comparison_ops" {|valid = var.count >= 0 && var.count <= 100|}

(* Test: Modulo operator *)
let test_modulo = roundtrip_test ~name:"modulo" {|remainder = var.num % 2|}

(* Test: Complex nested expression *)
let test_complex_nested_expr =
  roundtrip_test
    ~name:"complex_nested_expr"
    {|result = var.enabled ? upper(var.items[0]) : "default"|}

(* Test: For expression with condition *)
let test_for_with_condition =
  roundtrip_test ~name:"for_with_condition" {|filtered = [for x in var.items : x if x != "skip"]|}

(* Test: Ellipsis in function call *)
let test_ellipsis = roundtrip_test ~name:"ellipsis" {|merged = concat(var.list1, var.list2...)|}

(* Test: Attribute with numeric index *)
let test_numeric_attr = roundtrip_test ~name:"numeric_attr" {|item = var.tuple.0|}

(* Test: Integer as object key - Terraform coerces integer keys to strings *)
let test_integer_object_key =
  roundtrip_test ~name:"integer_object_key" {|listeners = {
  80  = "HTTP"
  443 = "HTTPS"
}|}

(* Test: Integer as object key - Terraform coerces integer keys to strings *)
let test_integer_object_key_and_value =
  roundtrip_test
    ~name:"integer_object_key_and_value"
    {|port_mapping = {
  80  = 8080
  443 = 8443
}|}

(* === for_each and count meta-arguments === *)

(* Test: Simple for_each with variable reference *)
let test_foreach_simple =
  roundtrip_test
    ~name:"foreach_simple"
    {|resource "aws_s3_bucket" "example" {
  for_each = local.buckets
  bucket = each.value
}|}

(* Test: count with integer literal *)
let test_count_integer =
  roundtrip_test
    ~name:"count_integer"
    {|resource "aws_instance" "example" {
  count = 3
  ami = "ami-123"
}|}

(* Test: count with variable reference *)
let test_count_variable =
  roundtrip_test
    ~name:"count_variable"
    {|resource "aws_instance" "example" {
  count = var.instance_count
  ami = "ami-123"
}|}

(* Test: count with conditional expression *)
let test_count_conditional =
  roundtrip_test
    ~name:"count_conditional"
    {|resource "aws_instance" "example" {
  count = var.enabled ? 1 : 0
  ami = "ami-123"
}|}

(* Test: for_each with inline object *)
let test_foreach_inline_object =
  roundtrip_test
    ~name:"foreach_inline_object"
    {|resource "aws_instance" "example" {
  for_each = {
    prod = "t2.large"
    dev = "t2.micro"
  }
  instance_type = each.value
}|}

(* Test: each.key and each.value references *)
let test_foreach_each_key_value =
  roundtrip_test
    ~name:"foreach_each_key_value"
    {|resource "aws_s3_bucket" "bucket" {
  for_each = var.bucket_configs
  bucket = each.key
  tags = {
    config = each.value
  }
}|}

(* Test: Module with for_each *)
let test_module_foreach =
  roundtrip_test
    ~name:"module_foreach"
    {|module "vpc" {
  for_each = var.vpcs
  source = "./modules/vpc"
  cidr = each.value.cidr
}|}

(* Test: Module with count *)
let test_module_count =
  roundtrip_test
    ~name:"module_count"
    {|module "vpc" {
  count = var.vpc_count
  source = "./modules/vpc"
}|}

(* === JSON representation tests === *)

(* Test: Expression encoded as interpolation string in JSON *)
let test_expr_json_interpolation =
  Oth.test ~name:"expr_json_interpolation" (fun _ ->
      let ast = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string {|foo = a + b|}) in
      let json = Hcl_parser_value_json.of_ast ast in
      let value = Yojson.Safe.Util.member "foo" json in
      Oth.Assert.eq
        ~eq:Yojson.Safe.equal
        ~pp:(fun fmt j -> Format.pp_print_string fmt (Yojson.Safe.to_string j))
        (`String "${ (a + b) }")
        value;
      ())

(* Test: Simple object encoded as native JSON object *)
let test_expr_json_object =
  Oth.test ~name:"expr_json_object" (fun _ ->
      let ast =
        Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string {|foo = {
  key = "value"
}|})
      in
      let json = Hcl_parser_value_json.of_ast ast in
      let value = Yojson.Safe.Util.member "foo" json in
      Oth.Assert.eq
        ~eq:Yojson.Safe.equal
        ~pp:(fun fmt j -> Format.pp_print_string fmt (Yojson.Safe.to_string j))
        (`Assoc [ ("key", `String "value") ])
        value;
      ())

(* === Failure tests for invalid JSON input === *)

(* Helper for testing expected failures *)
let failure_test ~name ~expected_err json =
  Oth.test ~name (fun _ ->
      let err =
        Oth.Assert.error_pp
          ~pp:(fun fmt _ -> Format.pp_print_string fmt "Expected error but got Ok")
          (Hcl_parser_value_json.to_ast json)
      in
      (* Verify we got the expected error variant *)
      match (err, expected_err) with
      | `Unexpected_json_type_err _, `Unexpected_json_type_err ("", "") -> ()
      | `Invalid_block_structure_err _, `Invalid_block_structure_err "" -> ()
      | `Invalid_expr_type_err _, `Invalid_expr_type_err "" -> ()
      | _ ->
          Oth.Assert.false_
            (Printf.sprintf
               "Wrong error type: got %s"
               (Hcl_parser_value_json.pp_err Format.str_formatter err;
                Format.flush_str_formatter ())))

(* Test: Top-level JSON array instead of object *)
let test_fail_top_level_array =
  failure_test
    ~name:"fail_top_level_array"
    ~expected_err:(`Unexpected_json_type_err ("", ""))
    (`List [ `String "foo"; `String "bar" ])

(* Test: Top-level JSON string instead of object *)
let test_fail_top_level_string =
  failure_test
    ~name:"fail_top_level_string"
    ~expected_err:(`Unexpected_json_type_err ("", ""))
    (`String "not an object")

(* Test: Top-level JSON number instead of object *)
let test_fail_top_level_number =
  failure_test
    ~name:"fail_top_level_number"
    ~expected_err:(`Unexpected_json_type_err ("", ""))
    (`Int 42)

(* Test: Top-level JSON null instead of object *)
let test_fail_top_level_null =
  failure_test ~name:"fail_top_level_null" ~expected_err:(`Unexpected_json_type_err ("", "")) `Null

(* Test: Top-level JSON bool instead of object *)
let test_fail_top_level_bool =
  failure_test
    ~name:"fail_top_level_bool"
    ~expected_err:(`Unexpected_json_type_err ("", ""))
    (`Bool true)

(* Test: Invalid expr type - Intlit is not a valid expression *)
let test_fail_intlit_expr =
  failure_test
    ~name:"fail_intlit_expr"
    ~expected_err:(`Invalid_expr_type_err "")
    (`Assoc [ ("value", `Intlit "12345678901234567890") ])

(* Test: Invalid expr type - Intlit inside a list triggers Invalid_expr_type_err *)
let test_fail_intlit_in_list =
  failure_test
    ~name:"fail_intlit_in_list"
    ~expected_err:(`Invalid_expr_type_err "")
    (`Assoc [ ("value", `List [ `String "a"; `Intlit "12345678901234567890" ]) ])

(* Test: Invalid expr type - Intlit in nested position.
   With schema, "resource" is treated as a labeled block, so the Intlit is encountered
   as a block structure error rather than an expression error. *)
let test_fail_nested_intlit =
  failure_test
    ~name:"fail_nested_intlit"
    ~expected_err:(`Invalid_block_structure_err "")
    (`Assoc [ ("resource", `Assoc [ ("aws_instance", `Intlit "999999999999999") ]) ])

(* Test: Repeated blocks with same type and no labels — uses schema-recognized precondition *)
let test_repeated_blocks_no_labels =
  roundtrip_test
    ~name:"repeated_blocks_no_labels"
    {|resource "aws_instance" "x" {
  ami = "ami-123"
  lifecycle {
    precondition {
      condition     = var.ami != ""
      error_message = "AMI required"
    }
    precondition {
      condition     = var.type != ""
      error_message = "Type required"
    }
  }
}|}

(* === Schema disambiguation tests === *)

(* Test: locals block with nested object attribute should not be confused with a labeled block *)
let test_locals_nested_object =
  roundtrip_test ~name:"locals_nested_object" {|locals {
  a = {
    key = "val"
  }
}|}

(* === Realistic integration tests === *)

(* Test: Realistic Terraform configuration combining multiple features *)
let test_realistic_terraform =
  roundtrip_test
    ~name:"realistic_terraform"
    {|terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "environment" {
  type = string
  default = "dev"
}

variable "bucket_names" {
  type = list(string)
  default = ["logs", "data"]
}

locals {
  common_tags = {
    Environment = var.environment
    ManagedBy = "terraform"
  }
  bucket_count = length(var.bucket_names)
}

resource "aws_s3_bucket" "main" {
  for_each = toset(var.bucket_names)
  bucket = "${var.environment}-${each.key}-bucket"
  tags = merge(local.common_tags, {
    Purpose = each.key
  })
}

resource "aws_instance" "web" {
  count = var.environment == "prod" ? 3 : 1
  ami = "ami-12345"
  instance_type = "t2.micro"
  tags = local.common_tags
}

output "bucket_ids" {
  value = [for k, v in aws_s3_bucket.main : v.id]
}

output "instance_count" {
  value = local.bucket_count > 0 ? length(aws_instance.web) : 0
}|}

(* === Bug-fix test: list of objects in output value === *)
let test_output_value_list_of_objects =
  roundtrip_test
    ~name:"output_value_list_of_objects"
    {|output "alert_rules" {
  description = "Summary of all configured alert rules"
  value = [
    {
      name     = "high_cpu"
      severity = "critical"
    },
    {
      name     = "low_disk"
      severity = "warning"
    },
    {
      name     = "memory"
      severity = "info"
    },
  ]
}|}

(* === Schema block roundtrip tests === *)

let test_schema_terraform =
  roundtrip_test ~name:"schema_terraform" {|terraform {
  required_version = ">= 1.0"
}|}

let test_schema_locals = roundtrip_test ~name:"schema_locals" {|locals {
  foo = "bar"
}|}

let test_schema_moved =
  roundtrip_test
    ~name:"schema_moved"
    {|moved {
  from = aws_instance.old
  to   = aws_instance.new
}|}

let test_schema_import =
  roundtrip_test ~name:"schema_import" {|import {
  to = aws_instance.example
  id = "i-abc123"
}|}

let test_schema_removed =
  roundtrip_test ~name:"schema_removed" {|removed {
  from = aws_instance.old
}|}

let test_schema_ephemeral =
  roundtrip_test
    ~name:"schema_ephemeral"
    {|ephemeral "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "my-secret"
}|}

let test_schema_action =
  roundtrip_test
    ~name:"schema_action"
    {|action "local_command" "notify" {
  count = 2
  config {
    command   = "echo"
    arguments = [var.message]
  }
}|}

let test_schema_resource_action_trigger =
  roundtrip_test
    ~name:"schema_resource_action_trigger"
    {|resource "terraform_data" "r" {
  input = "x"
  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.local_command.notify[0]]
    }
    action_trigger {
      events    = [after_update]
      condition = var.enabled
      actions   = [action.local_command.notify[1]]
    }
  }
}|}

let test_schema_provider =
  roundtrip_test ~name:"schema_provider" {|provider "aws" {
  region = "us-east-1"
}|}

let test_schema_check =
  roundtrip_test
    ~name:"schema_check"
    {|check "health" {
  assert {
    condition     = true
    error_message = "Health check failed"
  }
}|}

let test_schema_terraform_backend =
  roundtrip_test
    ~name:"schema_terraform_backend"
    {|terraform {
  backend "s3" {
    bucket = "my-bucket"
  }
}|}

let test_schema_terraform_cloud =
  roundtrip_test
    ~name:"schema_terraform_cloud"
    {|terraform {
  cloud {
    organization = "my-org"
  }
}|}

let test_schema_terraform_provider_meta =
  roundtrip_test
    ~name:"schema_terraform_provider_meta"
    {|terraform {
  provider_meta "aws" {
    module_name = "my-module"
  }
}|}

let test_schema_resource_lifecycle =
  roundtrip_test
    ~name:"schema_resource_lifecycle"
    {|resource "aws_instance" "x" {
  ami = "ami-123"
  lifecycle {
    create_before_destroy = true
  }
}|}

let test_schema_resource_connection =
  roundtrip_test
    ~name:"schema_resource_connection"
    {|resource "null_resource" "x" {
  connection {
    type = "ssh"
    host = "example.com"
  }
}|}

let test_schema_resource_provisioner =
  roundtrip_test
    ~name:"schema_resource_provisioner"
    {|resource "null_resource" "x" {
  provisioner "local-exec" {
    command = "echo hello"
  }
}|}

let test_schema_resource_lifecycle_precondition =
  roundtrip_test
    ~name:"schema_resource_lifecycle_precondition"
    {|resource "aws_instance" "x" {
  ami = "ami-123"
  lifecycle {
    precondition {
      condition     = var.ami != ""
      error_message = "AMI must be set"
    }
  }
}|}

let test_schema_resource_lifecycle_postcondition =
  roundtrip_test
    ~name:"schema_resource_lifecycle_postcondition"
    {|resource "aws_instance" "x" {
  ami = "ami-123"
  lifecycle {
    postcondition {
      condition     = self.id != ""
      error_message = "Instance must have an ID"
    }
  }
}|}

let test_schema_data_lifecycle =
  roundtrip_test
    ~name:"schema_data_lifecycle"
    {|data "http" "x" {
  url = "https://example.com"
  lifecycle {
    precondition {
      condition     = var.url != ""
      error_message = "URL required"
    }
  }
}|}

let test_schema_variable_validation =
  roundtrip_test
    ~name:"schema_variable_validation"
    {|variable "name" {
  type = string
  validation {
    condition     = length(var.name) > 0
    error_message = "Name must not be empty"
  }
}|}

let test_schema_output_precondition =
  roundtrip_test
    ~name:"schema_output_precondition"
    {|output "x" {
  value = "hello"
  precondition {
    condition     = var.ready
    error_message = "Not ready"
  }
}|}

let test_schema_check_data =
  roundtrip_test
    ~name:"schema_check_data"
    {|check "health" {
  data "http" "api" {
    url = "https://example.com/health"
  }
  assert {
    condition     = data.http.api.status_code == 200
    error_message = "API unhealthy"
  }
}|}

(* Attr-as-blocks: without provider schema, blocks normalize to list-of-objects attributes.
   See https://developer.hashicorp.com/terraform/language/attr-as-blocks *)
let test_attr_as_blocks_ingress =
  Oth.test ~name:"attr_as_blocks_ingress" (fun _ ->
      let ast =
        Oth.Assert.ok_pp
          ~pp:Hcl_ast.pp_err
          (Hcl_ast.of_string
             {|resource "aws_security_group" "example" {
  name = "test"
  ingress {
    from_port = 443
  }
}|})
      in
      let json = Hcl_parser_value_json.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp ~pp:Hcl_parser_value_json.pp_err (Hcl_parser_value_json.to_ast json)
      in
      let expected =
        Oth.Assert.ok_pp
          ~pp:Hcl_ast.pp_err
          (Hcl_ast.of_string
             {|resource "aws_security_group" "example" {
  name = "test"
  ingress = [{
    from_port = 443
  }]
}|})
      in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast expected roundtripped;
      ())

let test_attr_as_blocks_multiple_ingress =
  Oth.test ~name:"attr_as_blocks_multiple_ingress" (fun _ ->
      let ast =
        Oth.Assert.ok_pp
          ~pp:Hcl_ast.pp_err
          (Hcl_ast.of_string
             {|resource "aws_security_group" "example" {
  name = "test"
  ingress {
    from_port = 80
  }
  ingress {
    from_port = 443
  }
}|})
      in
      let json = Hcl_parser_value_json.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp ~pp:Hcl_parser_value_json.pp_err (Hcl_parser_value_json.to_ast json)
      in
      let expected =
        Oth.Assert.ok_pp
          ~pp:Hcl_ast.pp_err
          (Hcl_ast.of_string
             {|resource "aws_security_group" "example" {
  name = "test"
  ingress = [{
    from_port = 80
  }, {
    from_port = 443
  }]
}|})
      in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast expected roundtripped;
      ())

let test_attr_as_blocks_tags =
  Oth.test ~name:"attr_as_blocks_tags" (fun _ ->
      let ast =
        Oth.Assert.ok_pp
          ~pp:Hcl_ast.pp_err
          (Hcl_ast.of_string
             {|resource "aws_instance" "example" {
  ami = "ami-123"
  tags {
    name = "example"
  }
}|})
      in
      let json = Hcl_parser_value_json.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp ~pp:Hcl_parser_value_json.pp_err (Hcl_parser_value_json.to_ast json)
      in
      let expected =
        Oth.Assert.ok_pp
          ~pp:Hcl_ast.pp_err
          (Hcl_ast.of_string
             {|resource "aws_instance" "example" {
  ami = "ami-123"
  tags = [{
    name = "example"
  }]
}|})
      in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast expected roundtripped;
      ())

(* Comment property "//" tests *)
let test_comment_property_string =
  Oth.test ~name:"comment_property_string" (fun _ ->
      let json = `Assoc [ ("//", `String "This is a comment"); ("foo", `String "bar") ] in
      let ast =
        Oth.Assert.ok_pp ~pp:Hcl_parser_value_json.pp_err (Hcl_parser_value_json.to_ast json)
      in
      let expected = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string {|foo = "bar"|}) in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast expected ast;
      ())

let test_comment_property_object =
  Oth.test ~name:"comment_property_object" (fun _ ->
      let json =
        `Assoc
          [ ("//", `Assoc [ ("description", `String "managed by terraform") ]); ("count", `Int 42) ]
      in
      let ast =
        Oth.Assert.ok_pp ~pp:Hcl_parser_value_json.pp_err (Hcl_parser_value_json.to_ast json)
      in
      let expected = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string {|count = 42|}) in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast expected ast;
      ())

let test_comment_property_only =
  Oth.test ~name:"comment_property_only" (fun _ ->
      let json = `Assoc [ ("//", `String "just a comment") ] in
      let ast =
        Oth.Assert.ok_pp ~pp:Hcl_parser_value_json.pp_err (Hcl_parser_value_json.to_ast json)
      in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast [] ast;
      ())

let test_comment_property_nested_block =
  Oth.test ~name:"comment_property_nested_block" (fun _ ->
      let json =
        `Assoc
          [
            ( "resource",
              `Assoc
                [
                  ( "aws_instance",
                    `Assoc
                      [
                        ( "example",
                          `List
                            [
                              `Assoc
                                [
                                  ("//", `String "This resource creates an EC2 instance");
                                  ("ami", `String "ami-123");
                                ];
                            ] );
                      ] );
                ] );
          ]
      in
      let ast =
        Oth.Assert.ok_pp ~pp:Hcl_parser_value_json.pp_err (Hcl_parser_value_json.to_ast json)
      in
      let expected =
        Oth.Assert.ok_pp
          ~pp:Hcl_ast.pp_err
          (Hcl_ast.of_string {|resource "aws_instance" "example" {
  ami = "ami-123"
}|})
      in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast expected ast;
      ())

(* #1032 — the .tf.json loader must accept the two repeated-block encodings:
   multiple names under a type, and an array of bodies under a single label. *)
let count_resource_blocks json_string =
  let json = Yojson.Safe.from_string json_string in
  let ast = Oth.Assert.ok_pp ~pp:Hcl_parser_value_json.pp_err (Hcl_parser_value_json.to_ast json) in
  CCList.length
    (CCList.filter
       (function
         | Hcl_parser_value.Block { type_ = "resource"; _ } -> true
         | Hcl_parser_value.Block _ | Hcl_parser_value.Attribute _ -> false)
       ast)

let test_1032_repeated_blocks_multi_name =
  Oth.test ~name:"repeated_blocks_multi_name" (fun _ ->
      Oth.Assert.Eq.int
        ~expected:2
        ~actual:
          (count_resource_blocks
             {|{"resource": {"null_resource": {"a": {"foo": "x"}, "b": {"foo": "y"}}}}|}))

let test_1032_repeated_blocks_body_array =
  Oth.test ~name:"repeated_blocks_body_array" (fun _ ->
      Oth.Assert.Eq.int
        ~expected:2
        ~actual:
          (count_resource_blocks
             {|{"resource": {"null_resource": {"a": [{"foo": "x"}, {"foo": "y"}]}}}|}))

let test =
  Oth.parallel
    [
      test_1032_repeated_blocks_multi_name;
      test_1032_repeated_blocks_body_array;
      test_simple_attribute;
      test_attribute_int;
      test_attribute_bool;
      test_attribute_null;
      test_attribute_float;
      test_attribute_tuple;
      test_attribute_object;
      test_attribute_object_heredoc_build;
      test_block_no_labels;
      test_block_one_label;
      test_block_two_labels;
      test_multiple_blocks_same_type;
      test_expr_var_ref;
      test_expr_function_call;
      test_expr_conditional;
      test_expr_binary_op;
      test_expr_for_tuple;
      test_expr_for_object;
      test_expr_index;
      test_expr_attr_access;
      test_nested_blocks;
      test_multiple_nested_blocks;
      test_mixed_content;
      (* Edge cases *)
      test_string_with_dollar;
      test_empty_string;
      test_string_with_newlines;
      test_string_with_quotes;
      test_string_with_backslashes;
      test_string_with_tabs;
      test_tuple_mixed;
      test_nested_tuple;
      test_nested_object;
      test_expr_with_interpolated_string;
      test_multiple_interpolations;
      test_splat_expr;
      test_negative_number;
      test_unary_not;
      test_logical_ops;
      test_comparison_ops;
      test_modulo;
      test_complex_nested_expr;
      test_for_with_condition;
      test_ellipsis;
      test_numeric_attr;
      test_integer_object_key;
      test_integer_object_key_and_value;
      (* for_each and count meta-arguments *)
      test_foreach_simple;
      test_count_integer;
      test_count_variable;
      test_count_conditional;
      test_foreach_inline_object;
      test_foreach_each_key_value;
      test_module_foreach;
      test_module_count;
      (* JSON representation tests *)
      test_expr_json_interpolation;
      test_expr_json_object;
      (* Failure tests *)
      test_fail_top_level_array;
      test_fail_top_level_string;
      test_fail_top_level_number;
      test_fail_top_level_null;
      test_fail_top_level_bool;
      test_fail_intlit_expr;
      test_fail_intlit_in_list;
      test_fail_nested_intlit;
      (* Repeated blocks *)
      test_repeated_blocks_no_labels;
      (* Schema disambiguation *)
      test_locals_nested_object;
      (* Bug-fix test *)
      test_output_value_list_of_objects;
      (* Schema block roundtrip tests *)
      test_schema_terraform;
      test_schema_locals;
      test_schema_moved;
      test_schema_import;
      test_schema_removed;
      test_schema_ephemeral;
      test_schema_action;
      test_schema_resource_action_trigger;
      test_schema_provider;
      test_schema_check;
      test_schema_terraform_backend;
      test_schema_terraform_cloud;
      test_schema_terraform_provider_meta;
      test_schema_resource_lifecycle;
      test_schema_resource_connection;
      test_schema_resource_provisioner;
      test_schema_resource_lifecycle_precondition;
      test_schema_resource_lifecycle_postcondition;
      test_schema_data_lifecycle;
      test_schema_variable_validation;
      test_schema_output_precondition;
      test_schema_check_data;
      (* Realistic integration tests *)
      test_realistic_terraform;
      test_string_roundtrip_terraform_provider;
      test_string_roundtrip_data_source_with_backend;
      test_string_roundtrip_nested_file_in_interpolation;
      test_string_roundtrip_nested_filebase64_in_interpolation;
      test_string_roundtrip_escaped_interpolation;
      test_string_roundtrip_escaped_interpolation_with_text;
      test_string_roundtrip_escaped_directive;
      test_string_roundtrip_mixed_escape_and_interpolation;
      (* Attr-as-blocks tests *)
      test_attr_as_blocks_ingress;
      test_attr_as_blocks_multiple_ingress;
      test_attr_as_blocks_tags;
      (* Comment property "//" tests *)
      test_comment_property_string;
      test_comment_property_object;
      test_comment_property_only;
      test_comment_property_nested_block;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
