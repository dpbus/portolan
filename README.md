# Portolan

[![CI](https://github.com/dpbus/portolan/actions/workflows/ci.yml/badge.svg)](https://github.com/dpbus/portolan/actions/workflows/ci.yml)

Let LLMs and reporting tools query your Rails data safely: only the datasets,
dimensions, and measures you declare.

You declare each dataset in Ruby: the rows it covers, the dimensions it can be
grouped and filtered by, the measures it can count or sum, and worked examples.
A dashboard, a scheduled report, or an LLM sends a structured request naming a
dataset and what to see from it. Portolan checks the request against your
declaration, builds the SQL itself, and returns only what the declaration
allows. Nothing outside your code ever writes SQL or reaches a column you
didn't declare.

Giving an LLM database access usually means trusting every query it writes.
Portolan turns that around: it can only ask questions you have already made
answerable.

Portolan is in early development. Today it answers with aggregates: counts,
sums, and averages, grouped by the dimensions you declared. It requires
PostgreSQL.

## Installation

```ruby
gem 'portolan', '~> 0.1.0.pre'
```

Portolan needs Ruby 3.3 or later, ActiveRecord 7.1 or later, and PostgreSQL.

## Declaring a dataset

A dataset is a class. It says which rows it covers, how they may be grouped and
filtered, and what may be counted or summed.

```ruby
class Voyages < Portolan::Dataset
  description 'One row per voyage.'

  model Voyage
  relation { |fleet| Voyage.where(fleet:) }

  dimension :harbor, 'the harbor the voyage set out from'
  dimension :crew, 'how many sailors were aboard', type: :integer
  dimension :departed_at, 'when the ship set sail', type: :datetime
  dimension :flag, 'the flag the ship sailed under', joins: :ship, expression: 'ships.flag'
  dimension :fate, 'how the voyage ended', buckets: {
    arrived: { where: -> { Voyage.where.not(arrived_at: nil) }, description: 'reached its destination' },
    lost: -> { Voyage.where(lost: true) },
  }

  measure :voyages, 'number of voyages'
  measure :ships, 'number of ships that sailed', count_distinct: :ship_id
  measure :leagues, 'distance sailed, in leagues', sum: :leagues

  example 'How many voyages set out each month in 1325, and how did they end?',
    { measure: 'voyages', group_by: %w[departed_at fate], period: 'month',
      filters: [{ dimension: 'departed_at', op: 'between', values: %w[1325-01-01 1325-12-31] }] }
end
```

Register the datasets one audience may query:

```ruby
FLEET_DATASETS = Portolan::Registry.new(voyages: Voyages)
```

A registry checks every dataset when it is built, without touching the
database, so most mistakes in a declaration fail at boot, not in front of a
caller: a join through an association that doesn't exist, is a `has_many`, or
is polymorphic, and an example that isn't a valid request. Columns need the
database, so they are checked on the first query; add a spec that calls
`FLEET_DATASETS.check!` to catch a misspelled column before you deploy. Without
a `relation` block, a dataset covers every row of its model.

## Asking a question

```ruby
result = FLEET_DATASETS.aggregate(
  { dataset: 'voyages', measure: 'voyages', group_by: %w[fate], filters: [{ dimension: 'crew', op: 'gt', value: 20 }] },
  context: current_user.fleet
)

result.success? # => true
result.rows     # => [{ "fate" => "arrived", "voyages" => 12 }, { "fate" => "lost", "voyages" => 2 }]
result.to_h     # => the request, rows, notes, and definitions, ready for JSON
```

A request may come from Ruby with symbols, from JSON, or from Rails params. A
request with mistakes runs no SQL and returns every error at once, each saying
what is allowed:

```ruby
result.errors
# => ["unknown measure `ships_lost`; allowed: `voyages`, `ships`, `leagues`",
#     "filter 1: `crew`: `twenty` is not an integer"]
```

To let an LLM ask questions, give it three tools: one that returns
`registry.list`, one that returns `registry.describe(name)`, and one that
returns `registry.aggregate(arguments, context:).to_h`. The descriptions,
examples, and errors are written for a model to read and correct itself from.

## What keeps it safe

**The context comes from your authentication, never from the request.** The
relation block receives whatever you pass as `context:`, such as the signed-in
user or account, and uses it to scope rows. A request cannot name a context:
a `context` key is rejected as unknown. Never pass anything from the request as
the context.

**One row per something.** Each dataset has a grain: one row per voyage, per
order, per spool. Dimensions reach up from that row through `belongs_to`
associations, never down through `has_many`, because joining a `has_many`
repeats rows and inflates counts and sums; Portolan refuses such a join. To ask
across a `has_many`, either declare a dataset at the finer grain, or use a
bucket whose condition is a subquery:

```ruby
dimension :cargo, 'what the voyage carried', buckets: {
  spices: -> { Voyage.where(id: Hold.where(kind: 'spice').select(:voyage_id)) },
}
```

**Every query runs read-only, briefly, and in UTC.** Portolan runs each query in
its own transaction with writes blocked, a 5 second timeout on each SQL
statement, and the UTC time zone, then rolls it back. When Portolan opens the
transaction itself, PostgreSQL enforces read-only too; inside a transaction of
your own, Rails blocks writes. It only changes transaction-local settings, so
nothing leaks into your app's queries, including behind a pooler such as
PgBouncer in transaction mode. A query that times out, or a value the database
cannot use, comes back as an error.

**Values are always bound parameters.** Filter values never become SQL. A
filter on a column behaves like a Rails `where` condition on it, including
rounding a decimal to the column's scale. The only SQL in a query is what you
wrote in `expression:` and in bucket conditions.

## Reference

**Dataset declarations:** `description` and `model` are required. `relation`
is optional and receives the context; without it, a dataset covers
`model.all`. A dataset declares at least one `measure`, and any number of
`dimension`s and `example`s.

**Dimension types**

| Type | Operators | Periods |
|---|---|---|
| `:string` (default) | `eq`, `in` | |
| `:integer` | `eq`, `in`, `gt`, `lt`, `between` | |
| `:decimal` | `eq`, `in`, `gt`, `lt`, `between` | |
| `:boolean` | `eq` | |
| `:date` | `gt`, `lt`, `between` | `day`, `week`, `month`, `quarter`, `year` |
| `:datetime` | `gt`, `lt`, `between` | `hour`, `day`, `week`, `month`, `quarter`, `year` |

**Dimension options:** `type:`, `values:` (a fixed list for a string
dimension), `joins:` (a `belongs_to` association path, joined with a left
join, which needs an `expression:` naming the joined column), `expression:`
(SQL to read instead of a column), and `buckets:` (named
conditions, each a lambda returning a relation, with an optional description).

**Measures:** a plain `measure` counts rows; `count_distinct:`, `sum:`, and
`average:` take a column on the dataset's table.

**What `aggregate` accepts:** `dataset` and `measure` are required.
`group_by` takes up to three dimensions, at most one of them a date or
datetime, which then needs a `period`. `filters` is a list of
`{ dimension:, op:, value: }` (or `values:` for `in` and `between`); dates are
`YYYY-MM-DD`, and a day given for a datetime covers the whole day in UTC.
`limit` is 1 to 50 rows, and defaults to 50.

**Periods** start on Monday for weeks, are in UTC, and are labelled by their
first day (`2026-11-01`), or by the hour for `hour` (`2026-11-03T14:00Z`).
Periods with no rows are left out. A missing value comes back as `null` (`nil`
in Ruby).

## Current limitations

- PostgreSQL only.
- A row can fall into more than one bucket if their conditions overlap.
- Buckets need a model with a single-column primary key.
- When a query joins the same table twice, Rails aliases the second join; an
  `expression:` must name the table as Rails aliases it.
- Dimensions cannot join through a `has_many` or a polymorphic association; see
  the grain rule above.
- The timeout applies to each SQL statement, not to the whole request. Grouping
  by buckets runs one or two statements per bucket combination.
- Without a date dimension, the database sorts the groups by the measure and
  returns at most the row limit, largest first; a second statement counts
  them for the truncation note. A series loads every group, up to the group
  limit, so it can keep whole periods.
- Your `relation` block runs before Portolan's guard is in place, so it should
  build a relation, not run queries itself.
- The timeout (5 seconds), row limit (50), group limit for series (10,000), and
  number of bucket combinations (50) are fixed for now.

## Why the name?

A portolan is a medieval sailing chart of known coasts, harbors, and safe
routes. Portolan does the same for your data: you chart the datasets worth
visiting, and anything that queries them can go anywhere on the chart and
nowhere off it.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
