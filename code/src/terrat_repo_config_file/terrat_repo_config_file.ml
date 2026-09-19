let paths =
  [
    ".stategraph/config.yml";
    ".stategraph/config.yaml";
    ".terrateam/config.yml";
    ".terrateam/config.yaml";
  ]

let mem searched = Sln_list.String.mem searched paths

let is_changed =
  CCList.exists
    Terrat_change.Diff.(
      function
      | Add { filename } | Change { filename } | Remove { filename } -> mem filename
      | Move { filename; previous_filename } -> mem filename || mem previous_filename)
