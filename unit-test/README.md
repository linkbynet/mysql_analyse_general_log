# Unit-tests

# Contribute

When contributing to unit-tests, please add compressed sample of general log only if existing sample is not sufficient. In this case, please anonymise logs with something like :

```
sed -i \
  -e 's/`[a-zA-Z0-9_]\+\?`/`fake`/g' \
  -e "s/'[^']\+\?'/'fake'/g" \
  -e 's/[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/localhost/g' \
  -e 's/Connect\t[^@]\+@/Connect\tuser@/g' \
  general_log.testN
```
