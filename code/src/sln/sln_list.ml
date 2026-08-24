module String = struct
  let mem = CCList.mem ~eq:CCString.equal
  let sort = CCList.sort CCString.compare
end
