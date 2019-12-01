### Ipipdb

---

IPIP.net (Geoip) database file interface

---

### Usage
To lookup in a given database, you need to parse the database file first
and hold the results for later usage:

```erlang
{ok, Database} = ipipdb:parse_database("/path/to/ipip.ipdb").
```

Using the returned database contents, you could start looking up

```erlang
ipipdb:lookup("127.0.0.1", Database).
> {ok, #{}}
```

### License
[Apache 2.0](https://github.com/ksyu/ipipdb/blob/master/LICENSE)
