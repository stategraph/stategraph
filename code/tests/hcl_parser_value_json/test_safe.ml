let pp_json fmt j = Format.pp_print_string fmt (Yojson.Safe.pretty_to_string j)

(* Helper to run roundtrip test on the entire AST via Safe encoding *)
let roundtrip_test ~name hcl_string =
  Oth.test ~name (fun _ ->
      let ast = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string hcl_string) in
      let json = Hcl_parser_value_json.Safe.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp
          ~pp:Hcl_parser_value_json.Safe.pp_err
          (Hcl_parser_value_json.Safe.to_ast json)
      in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast ast roundtripped;
      ())

(* Helper: parse HCL, Safe-encode to JSON, Safe-decode back, print and assert the printed HCL
   matches the original. Catches roundtrip bugs that preserve AST equality but mangle the printed
   output. *)
let string_roundtrip_test ~name hcl_string =
  Oth.test ~name (fun _ ->
      let ast = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string hcl_string) in
      let json = Hcl_parser_value_json.Safe.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp
          ~pp:Hcl_parser_value_json.Safe.pp_err
          (Hcl_parser_value_json.Safe.to_ast json)
      in
      let result = Hcl_ast.To_string.ast roundtripped in
      Oth.Assert.Eq.string ~expected:hcl_string ~actual:result;
      ())

(* Regression for nested templates: the Safe.to_ast path for a `String JSON value parses template
   syntax back into a Template but, pre-fix, did not recursively transform the nested
   Expr.String "${path.module}/..." inside the Fun_call argument. At print time
   escape_hcl_string then mangled ${path.module} into $${path.module}, which tofu would read
   as a literal string rather than the module path. *)
let test_string_roundtrip_nested_file_in_interpolation_safe =
  string_roundtrip_test
    ~name:"safe_string_roundtrip_nested_file_in_interpolation"
    {|resource "terraform_data" "dup" {
  input = "${file("data.txt")}-${file("data.txt")}"
}|}

let test_string_roundtrip_nested_filebase64_in_interpolation_safe =
  string_roundtrip_test
    ~name:"safe_string_roundtrip_nested_filebase64_in_interpolation"
    {|resource "terraform_data" "mixed" {
  input = "${file("${path.module}/data.txt")}-${filebase64("${path.module}/data.txt")}"
}|}

(* Regression: a literal string written with the $${ / %%{ escape must survive the Safe JSON
   roundtrip as a literal, not be reinterpreted as an interpolation/directive. *)
let test_string_roundtrip_escaped_interpolation_safe =
  string_roundtrip_test ~name:"safe_string_roundtrip_escaped_interpolation" {|literal = "$${foo}"|}

let test_string_roundtrip_mixed_escape_and_interpolation_safe =
  string_roundtrip_test
    ~name:"safe_string_roundtrip_mixed_escape_and_interpolation"
    {|literal = "$${literal}-${var.x}"|}

(* Regression for the quoted-Template over-escaping mismatch: a string with an
   interpolation AND embedded escaped double-quotes (e.g. a google_logging_metric
   filter) is an Expr.Template. Its literal parts carry the embedded quotes; the
   Safe round-trip must NOT multiply the backslashes. Pre-fix, each store/reify pass
   re-escaped the already-escaped quotes, growing the backslash run exponentially. *)
let test_string_roundtrip_template_embedded_quotes_safe =
  string_roundtrip_test
    ~name:"safe_string_roundtrip_template_embedded_quotes"
    {|filter = "resource.type=\"cloud_run_revision\" AND name=\"${var.x}\""|}

(* The exact production expression (google_logging_metric.cloudfunction_uptime_metric
   filter) that regressed, recovered from the SG_TFEVAL diagnostics dump. Must
   survive the Safe round-trip byte-for-byte (no backslash multiplication). *)
let test_string_roundtrip_production_metric_filter_safe =
  string_roundtrip_test
    ~name:"safe_string_roundtrip_production_metric_filter"
    {|filter = "resource.type=\"cloud_run_revision\" AND jsonPayload.result=~\"^(ERROR|SUCCESS|SKIP)$\" AND resource.labels.service_name=\"${module.cloudfunction.cloudfunction_name}\""|}

(* Helper: parse HCL, convert to Safe JSON, assert JSON equals expected *)
let json_test ~name hcl_string expected_json =
  Oth.test ~name (fun _ ->
      let ast = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string hcl_string) in
      let json = Hcl_parser_value_json.Safe.of_ast ast in
      Oth.Assert.eq ~eq:Yojson.Safe.equal ~pp:pp_json expected_json json;
      ())

(* === One-way HCL -> JSON tests === *)

let test_json_simple_int =
  json_test ~name:"json_simple_int" {|foo = 5|} (`List [ `Assoc [ ("foo", `Int 5) ] ])

let test_json_simple_string =
  json_test ~name:"json_simple_string" {|foo = "bar"|} (`List [ `Assoc [ ("foo", `String "bar") ] ])

let test_json_simple_bool =
  json_test
    ~name:"json_simple_bool"
    {|enabled = true|}
    (`List [ `Assoc [ ("enabled", `Bool true) ] ])

let test_json_simple_null =
  json_test ~name:"json_simple_null" {|value = null|} (`List [ `Assoc [ ("value", `Null) ] ])

let test_json_simple_float =
  json_test ~name:"json_simple_float" {|ratio = 3.14|} (`List [ `Assoc [ ("ratio", `Float 3.14) ] ])

let test_json_list_wrapped =
  json_test
    ~name:"json_list_wrapped"
    {|items = ["a", "b"]|}
    (`List [ `Assoc [ ("items", `String "${ [\"a\", \"b\"] }") ] ])

let test_json_object_wrapped =
  json_test
    ~name:"json_object_wrapped"
    {|config = {
  key = "value"
}|}
    (`List [ `Assoc [ ("config", `String "${ {key = \"value\"\n} }") ] ])

let test_json_var_ref =
  json_test
    ~name:"json_var_ref"
    {|region = var.region|}
    (`List [ `Assoc [ ("region", `String "${ var.region }") ] ])

let test_json_block_with_labels =
  json_test
    ~name:"json_block_with_labels"
    {|resource "aws_s3_bucket" "example" {
  bucket = "test"
}|}
    (`List
       [
         `Assoc
           [
             ("type", `String "resource");
             ("labels", `List [ `String "aws_s3_bucket"; `String "example" ]);
             ("attrs", `List [ `Assoc [ ("bucket", `String "test") ] ]);
           ];
       ])

let test_json_block_no_labels =
  json_test
    ~name:"json_block_no_labels"
    {|locals {
  foo = "bar"
}|}
    (`List
       [
         `Assoc
           [
             ("type", `String "locals");
             ("labels", `List []);
             ("attrs", `List [ `Assoc [ ("foo", `String "bar") ] ]);
           ];
       ])

let test_json_nested_blocks =
  json_test
    ~name:"json_nested_blocks"
    {|resource "aws_security_group" "example" {
  name = "test"
  ingress {
    from_port = 443
  }
}|}
    (`List
       [
         `Assoc
           [
             ("type", `String "resource");
             ("labels", `List [ `String "aws_security_group"; `String "example" ]);
             ( "attrs",
               `List
                 [
                   `Assoc [ ("name", `String "test") ];
                   `Assoc
                     [
                       ("type", `String "ingress");
                       ("labels", `List []);
                       ("attrs", `List [ `Assoc [ ("from_port", `Int 443) ] ]);
                     ];
                 ] );
           ];
       ])

let test_json_multiple_same_type_blocks =
  json_test
    ~name:"json_multiple_same_type_blocks"
    {|resource "aws_security_group" "example" {
  ingress {
    from_port = 80
  }
  ingress {
    from_port = 443
  }
}|}
    (`List
       [
         `Assoc
           [
             ("type", `String "resource");
             ("labels", `List [ `String "aws_security_group"; `String "example" ]);
             ( "attrs",
               `List
                 [
                   `Assoc
                     [
                       ("type", `String "ingress");
                       ("labels", `List []);
                       ("attrs", `List [ `Assoc [ ("from_port", `Int 80) ] ]);
                     ];
                   `Assoc
                     [
                       ("type", `String "ingress");
                       ("labels", `List []);
                       ("attrs", `List [ `Assoc [ ("from_port", `Int 443) ] ]);
                     ];
                 ] );
           ];
       ])

let test_json_id_label =
  json_test
    ~name:"json_id_label"
    {|resource foo {
  bar = 1
}|}
    (`List
       [
         `Assoc
           [
             ("type", `String "resource");
             ("labels", `List [ `String "${ foo }" ]);
             ("attrs", `List [ `Assoc [ ("bar", `Int 1) ] ]);
           ];
       ])

(* === Roundtrip tests === *)

let test_simple_attribute = roundtrip_test ~name:"simple_attribute" {|foo = "bar"|}
let test_attribute_int = roundtrip_test ~name:"attribute_int" {|count = 42|}
let test_attribute_bool = roundtrip_test ~name:"attribute_bool" {|enabled = true|}
let test_attribute_null = roundtrip_test ~name:"attribute_null" {|value = null|}
let test_attribute_float = roundtrip_test ~name:"attribute_float" {|ratio = 3.14|}
let test_attribute_tuple = roundtrip_test ~name:"attribute_tuple" {|items = ["a", "b", "c"]|}

let test_attribute_object = roundtrip_test ~name:"attribute_object" {|config = {
  key = "value"
}|}

let test_block_no_labels = roundtrip_test ~name:"block_no_labels" {|locals {
  foo = "bar"
}|}

let test_block_one_label =
  roundtrip_test ~name:"block_one_label" {|variable "name" {
  default = "value"
}|}

let test_block_two_labels =
  roundtrip_test
    ~name:"block_two_labels"
    {|resource "aws_s3_bucket" "example" {
  bucket = "test"
}|}

let test_multiple_blocks_same_type =
  roundtrip_test
    ~name:"multiple_blocks_same_type"
    {|resource "aws_s3_bucket" "first" {
  bucket = "bucket1"
}
resource "aws_s3_bucket" "second" {
  bucket = "bucket2"
}|}

let test_expr_var_ref = roundtrip_test ~name:"expr_var_ref" {|region = var.region|}

let test_expr_function_call =
  roundtrip_test ~name:"expr_function_call" {|upper_name = upper(var.name)|}

let test_expr_conditional =
  roundtrip_test ~name:"expr_conditional" {|status = var.enabled ? "yes" : "no"|}

let test_expr_binary_op = roundtrip_test ~name:"expr_binary_op" {|total = var.count + 10|}

let test_expr_for_tuple =
  roundtrip_test ~name:"expr_for_tuple" {|names = [for x in var.items : upper(x)]|}

let test_expr_for_object =
  roundtrip_test ~name:"expr_for_object" {|mapping = {
  for k, v in var.items :
  k => upper(v)
}|}

let test_expr_index = roundtrip_test ~name:"expr_index" {|first = var.items[0]|}

let test_expr_attr_access =
  roundtrip_test ~name:"expr_attr_access" {|name = aws_instance.example.id|}

let test_nested_blocks =
  roundtrip_test
    ~name:"nested_blocks"
    {|resource "aws_security_group" "example" {
  name = "test"
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
  }
}|}

let test_multiple_nested_blocks =
  roundtrip_test
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

let test_mixed_content =
  roundtrip_test
    ~name:"mixed_content"
    {|resource "aws_instance" "example" {
  ami = "ami-123"
  instance_type = "t2.micro"
  tags {
    name = "example"
  }
}|}

let test_string_with_dollar = roundtrip_test ~name:"string_with_dollar" {|price = "$100"|}
let test_empty_string = roundtrip_test ~name:"empty_string" {|empty = ""|}

let test_string_with_newlines =
  roundtrip_test ~name:"string_with_newlines" {|multiline = "line1\nline2\nline3"|}

let test_string_with_quotes = roundtrip_test ~name:"string_with_quotes" {|quoted = "say \"hello\""|}

let test_string_with_backslashes =
  roundtrip_test ~name:"string_with_backslashes" {|path = "C:\\Users\\test"|}

let test_string_with_tabs = roundtrip_test ~name:"string_with_tabs" {|tabbed = "col1\tcol2"|}

let test_tuple_mixed =
  roundtrip_test ~name:"tuple_mixed" {|mixed = ["simple", var.complex, 42, true]|}

let test_nested_tuple = roundtrip_test ~name:"nested_tuple" {|nested = [["a", "b"], ["c", "d"]]|}

let test_nested_object =
  roundtrip_test ~name:"nested_object" {|outer = {
  inner = {
    deep = "value"
  }
}|}

let test_expr_with_interpolated_string =
  roundtrip_test ~name:"expr_with_interpolated_string" {|greeting = "Hello, ${var.name}!"|}

let test_multiple_interpolations =
  roundtrip_test ~name:"multiple_interpolations" {|combined = "${var.first} and ${var.second}"|}

let test_splat_expr = roundtrip_test ~name:"splat_expr" {|all_ids = aws_instance.example[*].id|}
let test_negative_number = roundtrip_test ~name:"negative_number" {|offset = -10|}
let test_unary_not = roundtrip_test ~name:"unary_not" {|disabled = !var.enabled|}
let test_logical_ops = roundtrip_test ~name:"logical_ops" {|condition = var.a && var.b || var.c|}

let test_comparison_ops =
  roundtrip_test ~name:"comparison_ops" {|valid = var.count >= 0 && var.count <= 100|}

let test_modulo = roundtrip_test ~name:"modulo" {|remainder = var.num % 2|}

let test_complex_nested_expr =
  roundtrip_test
    ~name:"complex_nested_expr"
    {|result = var.enabled ? upper(var.items[0]) : "default"|}

let test_for_with_condition =
  roundtrip_test ~name:"for_with_condition" {|filtered = [for x in var.items : x if x != "skip"]|}

let test_ellipsis = roundtrip_test ~name:"ellipsis" {|merged = concat(var.list1, var.list2...)|}
let test_numeric_attr = roundtrip_test ~name:"numeric_attr" {|item = var.tuple.0|}

let test_integer_object_key =
  roundtrip_test ~name:"integer_object_key" {|listeners = {
  80  = "HTTP"
  443 = "HTTPS"
}|}

let test_integer_object_key_and_value =
  roundtrip_test
    ~name:"integer_object_key_and_value"
    {|port_mapping = {
  80  = 8080
  443 = 8443
}|}

let test_foreach_simple =
  roundtrip_test
    ~name:"foreach_simple"
    {|resource "aws_s3_bucket" "example" {
  for_each = local.buckets
  bucket = each.value
}|}

let test_count_integer =
  roundtrip_test
    ~name:"count_integer"
    {|resource "aws_instance" "example" {
  count = 3
  ami = "ami-123"
}|}

let test_count_variable =
  roundtrip_test
    ~name:"count_variable"
    {|resource "aws_instance" "example" {
  count = var.instance_count
  ami = "ami-123"
}|}

let test_count_conditional =
  roundtrip_test
    ~name:"count_conditional"
    {|resource "aws_instance" "example" {
  count = var.enabled ? 1 : 0
  ami = "ami-123"
}|}

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

let test_module_foreach =
  roundtrip_test
    ~name:"module_foreach"
    {|module "vpc" {
  for_each = var.vpcs
  source = "./modules/vpc"
  cidr = each.value.cidr
}|}

let test_module_count =
  roundtrip_test
    ~name:"module_count"
    {|module "vpc" {
  count = var.vpc_count
  source = "./modules/vpc"
}|}

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

let test_locals_nested_object =
  roundtrip_test ~name:"locals_nested_object" {|locals {
  a = {
    key = "val"
  }
}|}

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

(* Safe encoding preserves blocks as blocks, so attr-as-block HCL roundtrips correctly *)
let test_attr_as_blocks_ingress =
  roundtrip_test
    ~name:"attr_as_blocks_ingress"
    {|resource "aws_security_group" "example" {
  name = "test"
  ingress {
    from_port = 443
  }
}|}

let test_attr_as_blocks_multiple_ingress =
  roundtrip_test
    ~name:"attr_as_blocks_multiple_ingress"
    {|resource "aws_security_group" "example" {
  name = "test"
  ingress {
    from_port = 80
  }
  ingress {
    from_port = 443
  }
}|}

let test_attr_as_blocks_tags =
  roundtrip_test
    ~name:"attr_as_blocks_tags"
    {|resource "aws_instance" "example" {
  ami = "ami-123"
  tags {
    name = "example"
  }
}|}

(* Block label Id roundtrip — unquoted labels should survive the roundtrip *)
let test_id_label_roundtrip =
  roundtrip_test ~name:"id_label_roundtrip" {|resource foo {
  bar = 1
}|}

let test_id_and_lit_labels_roundtrip =
  roundtrip_test ~name:"id_and_lit_labels_roundtrip" {|resource foo "bar" {
  baz = 2
}|}

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

let test_provider_default_tags =
  roundtrip_test
    ~name:"provider_default_tags"
    {|provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      ManagedBy = "OpenTofu"
    }
  }
}|}

(* === HEREDOC tests === *)

let test_heredoc_roundtrip =
  roundtrip_test ~name:"heredoc_roundtrip" "script = <<EOT\nline one\nline two\nEOT"

let test_heredoc_indented_roundtrip =
  roundtrip_test ~name:"heredoc_indented_roundtrip" "script = <<-EOT\n  line one\n  line two\n  EOT"

let test_heredoc_empty_body_roundtrip =
  roundtrip_test ~name:"heredoc_empty_body_roundtrip" "blank = <<EOT\nEOT"

let test_heredoc_with_interpolation_roundtrip =
  roundtrip_test
    ~name:"heredoc_with_interpolation_roundtrip"
    "greeting = <<EOT\nHello, ${var.name}!\nEOT"

(* A heredoc carrying multiple interpolations must Safe-roundtrip as a
   [Template_heredoc] with all its references preserved. *)
let test_heredoc_multi_interpolation_roundtrip =
  roundtrip_test
    ~name:"heredoc_multi_interpolation_roundtrip"
    "msg = <<EOT\n${local.a}-${var.b}\nEOT"

(* A literal [$${...}] inside a heredoc body must survive the Safe roundtrip as
   a literal, not be reinterpreted as an interpolation — exercises the
   [escape_literal] path of the [Template_heredoc] renderer. *)
let test_heredoc_escaped_interpolation_roundtrip =
  roundtrip_test
    ~name:"heredoc_escaped_interpolation_roundtrip"
    "msg = <<EOT\nliteral $${not_interp} and ${var.real}\nEOT"

let test_heredoc_inside_block_roundtrip =
  roundtrip_test
    ~name:"heredoc_inside_block_roundtrip"
    {|resource "null_resource" "example" {
  triggers = {
    script = <<EOT
run me
EOT
  }
}|}

let test_heredoc_in_fn_call_in_object_roundtrip =
  roundtrip_test
    ~name:"heredoc_in_fn_call_in_object_roundtrip"
    {|config = {
  text = chomp(<<EOT
hello
world
EOT
)
}|}

let test_json_heredoc =
  json_test
    ~name:"json_heredoc"
    {|script = <<EOT
hello
world
EOT|}
    (`List [ `Assoc [ ("script", `String "${ <<EOT\nhello\nworld\nEOT\n }") ] ])

(* A [<<-] (flush) heredoc has its common leading whitespace stripped at parse time
   (see hcl_lexer.ml [strip_heredoc_indent]), so the reified [${ <<EOT ... }] wrapper
   carries the already-stripped body — the value tofu evaluates then matches the
   committed [<<-] value. Here the 2-space indent on [  hello] is removed. *)
let test_json_heredoc_indented =
  json_test
    ~name:"json_heredoc_indented"
    {|script = <<-EOT
  hello
  EOT|}
    (`List [ `Assoc [ ("script", `String "${ <<EOT\nhello\nEOT\n }") ] ])

(* Helper: round-trip an AST (rather than an HCL source string) through the Safe encoding and
   back, asserting the result equals [expected]. Needed for ASTs that cannot be written as HCL
   source — e.g. an object whose key is an [Obj_key.Bare] that is not a valid bareword identifier.
   Such keys arise from JSON-sourced objects (see Hcl_parser_value_json.json_to_expr, which maps
   every JSON object key to [Obj_key.Bare]). [expected] may differ from [ast] where the round-trip
   normalizes a representation (e.g. a non-identifier [Bare] key is quoted on print, so it returns
   as [Quoted]). *)
let ast_roundtrip_test ~name ~expected ast =
  Oth.test ~name (fun _ ->
      let json = Hcl_parser_value_json.Safe.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp
          ~pp:Hcl_parser_value_json.Safe.pp_err
          (Hcl_parser_value_json.Safe.to_ast json)
      in
      Oth.Assert.eq ~eq:Hcl_ast.equal ~pp:Hcl_ast.To_string.pp_ast expected roundtripped;
      ())

(* Regression: a JSON-sourced object keyed by a UUID becomes [Obj_key.Bare "3ae50eb3-..."]. The
   Safe encoding wraps the object as an interpolation "${ {...} }"; To_string quotes the key (it is
   not a valid bare object key), so Safe.to_ast re-parses it as [Obj_key.Quoted] instead of failing
   with [`Safe_invalid_expr_err]. The value is otherwise preserved. *)
let test_object_bare_uuid_key_roundtrip =
  ast_roundtrip_test
    ~name:"object_bare_uuid_key_roundtrip"
    [
      Hcl_parser_value.Attribute
        ( "collector_id",
          Hcl_parser_value.Expr.Object
            [
              ( Hcl_parser_value.Obj_key.Bare "3ae50eb3-aae9-4cf2-a6cc-282e998b3e6d",
                Hcl_parser_value.Expr.Tuple [ Hcl_parser_value.Expr.String "ARUBA_WIRELESS" ] );
            ] );
    ]
    ~expected:
      [
        Hcl_parser_value.Attribute
          ( "collector_id",
            Hcl_parser_value.Expr.Object
              [
                ( Hcl_parser_value.Obj_key.Quoted "3ae50eb3-aae9-4cf2-a6cc-282e998b3e6d",
                  Hcl_parser_value.Expr.Tuple [ Hcl_parser_value.Expr.String "ARUBA_WIRELESS" ] );
              ] );
      ]

(* === Failure tests === *)

let test_fail_top_level_object =
  Oth.test ~name:"fail_top_level_object" (fun _ ->
      match
        Oth.Assert.error_pp
          ~pp:(fun fmt _ -> Format.pp_print_string fmt "Expected error but got Ok")
          (Hcl_parser_value_json.Safe.to_ast (`Assoc [ ("foo", `String "bar") ]))
      with
      | `Safe_unexpected_type_err _ -> ()
      | _ -> Oth.Assert.false_ "Wrong error type")

let test_fail_top_level_string =
  Oth.test ~name:"fail_top_level_string" (fun _ ->
      match
        Oth.Assert.error_pp
          ~pp:(fun fmt _ -> Format.pp_print_string fmt "Expected error but got Ok")
          (Hcl_parser_value_json.Safe.to_ast (`String "not an array"))
      with
      | `Safe_unexpected_type_err _ -> ()
      | _ -> Oth.Assert.false_ "Wrong error type")

let test_fail_multi_key_object =
  Oth.test ~name:"fail_multi_key_object" (fun _ ->
      match
        Oth.Assert.error_pp
          ~pp:(fun fmt _ -> Format.pp_print_string fmt "Expected error but got Ok")
          (Hcl_parser_value_json.Safe.to_ast
             (`List [ `Assoc [ ("foo", `Int 1); ("bar", `Int 2) ] ]))
      with
      | `Safe_invalid_json_structure_err _ -> ()
      | _ -> Oth.Assert.false_ "Wrong error type")

(* A template that is one interpolation with whitespace around it is a padded STRING, not a wrapped
   expression. [Safe.of_expr] wraps a stored expression as ["${ <expr> }"] with its padding inside
   the braces, so whitespace outside them is the author's own text: reading [" ${var.x} "] back as
   [var.x] drops the padding, and every later plan renders an in-place update whose two sides differ
   only in whitespace. It also changes the type, since an unwrapped number stops being stringified.

   The padding is interpolated rather than written literally so no formatter can strip it and leave a
   test that proves nothing. *)
let test_string_roundtrip_padded_interpolation_safe =
  string_roundtrip_test
    ~name:"string_roundtrip_padded_interpolation_safe"
    (Printf.sprintf {|x = "%s${var.name}%s"|} "  " "   ")

let test_string_roundtrip_padded_interpolation_leading_safe =
  string_roundtrip_test
    ~name:"string_roundtrip_padded_interpolation_leading_safe"
    (Printf.sprintf {|x = "%s${var.name}"|} " ")

let test_string_roundtrip_padded_interpolation_trailing_safe =
  string_roundtrip_test
    ~name:"string_roundtrip_padded_interpolation_trailing_safe"
    (Printf.sprintf {|x = "${var.name}%s"|} " ")

(* The unpadded form is how [Safe.of_expr] encodes a stored expression, so it must keep unwrapping to
   the bare expression -- that is the encoding, not a user's template. *)
let test_string_roundtrip_bare_interpolation_safe =
  Oth.test ~name:"string_roundtrip_bare_interpolation_safe" (fun _ ->
      let ast = Oth.Assert.ok_pp ~pp:Hcl_ast.pp_err (Hcl_ast.of_string {|x = "${var.name}"|}) in
      let json = Hcl_parser_value_json.Safe.of_ast ast in
      let roundtripped =
        Oth.Assert.ok_pp
          ~pp:Hcl_parser_value_json.Safe.pp_err
          (Hcl_parser_value_json.Safe.to_ast json)
      in
      Oth.Assert.Eq.string ~expected:"x = var.name" ~actual:(Hcl_ast.To_string.ast roundtripped))

let test =
  Oth.parallel
    [
      (* One-way JSON representation tests *)
      test_json_simple_int;
      test_json_simple_string;
      test_json_simple_bool;
      test_json_simple_null;
      test_json_simple_float;
      test_json_list_wrapped;
      test_json_object_wrapped;
      test_json_var_ref;
      test_json_block_with_labels;
      test_json_block_no_labels;
      test_json_nested_blocks;
      test_json_multiple_same_type_blocks;
      test_json_id_label;
      (* Roundtrip tests *)
      test_simple_attribute;
      test_attribute_int;
      test_attribute_bool;
      test_attribute_null;
      test_attribute_float;
      test_attribute_tuple;
      test_attribute_object;
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
      (* Repeated blocks *)
      test_repeated_blocks_no_labels;
      (* Schema disambiguation *)
      test_locals_nested_object;
      (* Realistic integration test *)
      test_realistic_terraform;
      test_output_value_list_of_objects;
      (* Attr-as-blocks — Safe preserves blocks, so these are plain roundtrips *)
      test_attr_as_blocks_ingress;
      test_attr_as_blocks_multiple_ingress;
      test_attr_as_blocks_tags;
      (* Block label Id tests *)
      test_id_label_roundtrip;
      test_id_and_lit_labels_roundtrip;
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
      (* Provider with nested block and object attribute *)
      test_provider_default_tags;
      (* HEREDOC tests *)
      test_heredoc_roundtrip;
      test_heredoc_indented_roundtrip;
      test_heredoc_empty_body_roundtrip;
      test_heredoc_with_interpolation_roundtrip;
      test_heredoc_multi_interpolation_roundtrip;
      test_heredoc_escaped_interpolation_roundtrip;
      test_heredoc_inside_block_roundtrip;
      test_heredoc_in_fn_call_in_object_roundtrip;
      test_json_heredoc;
      test_json_heredoc_indented;
      (* Regression: JSON-sourced object with a non-identifier (UUID) bare key *)
      test_object_bare_uuid_key_roundtrip;
      (* Failure tests *)
      test_fail_top_level_object;
      test_fail_top_level_string;
      test_fail_multi_key_object;
      (* String-roundtrip regressions for nested templates *)
      test_string_roundtrip_nested_file_in_interpolation_safe;
      test_string_roundtrip_nested_filebase64_in_interpolation_safe;
      test_string_roundtrip_escaped_interpolation_safe;
      test_string_roundtrip_mixed_escape_and_interpolation_safe;
      test_string_roundtrip_template_embedded_quotes_safe;
      test_string_roundtrip_production_metric_filter_safe;
      test_string_roundtrip_padded_interpolation_safe;
      test_string_roundtrip_padded_interpolation_leading_safe;
      test_string_roundtrip_padded_interpolation_trailing_safe;
      test_string_roundtrip_bare_interpolation_safe;
    ]

let () =
  Random.self_init ();
  Oth.run ~file:__FILE__ ~setup:(fun () -> Ok ()) ~teardown:(fun _ -> ()) (fun _ -> test)
