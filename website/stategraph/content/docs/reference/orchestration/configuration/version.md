---
title: version
description: Reference for the version key in .stategraph/config.yml. The configuration file format version, which must be the quoted string "1".
order: 26
---


`version` sets the format version of `.stategraph/config.yml`. The only supported value is `"1"`. It is also the default, so you can leave the key out.

## Default Configuration

```yaml
version: "1"
```

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `version` | string | The configuration file format version. Default is `"1"`. |

- Any value other than `"1"` is a configuration error.
- Quote the value. An unquoted `1` is a YAML integer, and the key must be a string.
- A new configuration format will get a new `version` value, and the release notes will document it.

## Examples

### Specifying the Version Explicitly

```yaml
version: "1"
```

This is the same as leaving the key out.

## Related

- [Configuration overview](/docs/orchestration/configuration)
- [enabled](/docs/reference/orchestration/configuration/enabled)
