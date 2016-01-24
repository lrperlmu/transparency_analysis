## Reshaped data files

### Binary data
* accuracy.csv
* language.csv
* pointing.csv

The original data for these has a value of 0 or 1 for each command. (Blanks are counted as 0.)
Reshaped data is aggregated by sum. (For example, the value for baseline_P1 is a sum of the values for
each command in Part 1 of the baseline.)

### Real valued data
Reshaped data is aggregated by average. (For example, the value for baseline_P1 is an average of the
values for each command in Part 1 of the baseline.)

#### No blanks allowed
* attempt_times.csv
* number_of_words.csv
* number_of_attempts.csv

Every command has data for these metrics. So in every P1, the value is an average of 10 values, and in every
P2, the value is an average of 5 values.

#### Blanks ignored
* completion_times.csv

This metric applies only to commands that were confirmed successfully. Some commands were not confirmed
successfully, so the original data contains blanks. If blanks exist, they are ignored. So if a participant
successfully completed 8 out of 10 commands in baseline_P1, then the value in that column is an average of
8 values.
