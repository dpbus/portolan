# Portolan

Let LLMs and reporting tools query your Rails data safely: only the datasets,
dimensions, and measures you declare.

You declare each dataset in Ruby: the rows it covers, the dimensions it can be
grouped and filtered by, the measures it can count or sum, and examples. A
dashboard, a scheduled report, or an LLM sends a structured request naming a
dataset and what to see from it. Portolan checks the request against your
declaration, builds the SQL itself, and returns only what the declaration
allows. Nothing outside your code ever writes SQL or reaches a column you
didn't declare.

Giving an LLM database access usually means trusting every query it writes.
Portolan turns that around: it can only ask questions you have already made
answerable.

Portolan is in early development and not yet released.

## Why the name?

A portolan is a medieval sailing chart of known coasts, harbors, and safe
routes. Portolan does the same for your data: you chart the datasets worth
visiting, and anything that queries them can go anywhere on the chart and
nowhere off it.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
