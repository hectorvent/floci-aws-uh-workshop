# Catch-up and solutions

- **Lab 1 stuck?** Skip it. Lab 2 builds everything from scratch (run `floci aws reset -y` first).
- **Lab 2 stuck?** Compare your `lab2-terraform/` with a fresh clone, or ask a helper. `terraform apply` must point at `http://localhost:4566`.
- **Lab 3 spoilers:** [`lab3.diff`](lab3.diff) is the fix. Apply it with `cd lab3-agent && patch -p1 < ../solutions/lab3.diff`.
  Try it with your agent (or by hand) first. Reading the errors is the whole point of the lab.
