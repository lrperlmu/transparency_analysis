### Columns
* First column is always participant ID. 
* Subsequent columns contain a word and a number separted by underscore, e.g. `robot_09`
  * word: `robot` = Baseline; `monitor` = Monitor condition; `oculus` = Oculus condition
  * number: 
      * If in range [1,15] it refers to Command 1 through Command 15.
      * If in range [1,2] it refers to Part 1 and Part 2. 
            * Part 1 consists of Commands 1-10
            * Part 2 consists of Commands 11-15

### Participant condition ordering
* Odd numbered participants, except #5, have (Baseline | Monitor | Oculus)
* Even numbered participants, and #5, have (Baseline | Oculus | Monitor)

### Raw Data
These files are not the raw data. Raw data is in log format in a different repository.
Where these files aggregate by Part, I can obtain finer-grained data if necessary
by changing my log-parsing code.

### Files
* `accuracy_2.csv` - number of commands positively confirmed in four of fewer attempts
* `attempt_times.csv` - average time per attempt (attempt = trying to give a command)
* `completion_times.csv` - total time until positive confirmation (includes all attempts) 
  for commands positively confirmed within four attempts
* `language.csv` - Whether the user's language was relevant in inferring the command 
  (1=yes, 0=no)
* `number_of_attempts.csv` - Number of attempts to convey the command. If 4 or fewer,
   we know it was positively confirmed.
* `number_of_words.csv` - Number of words uttered by the user (includes all attempts)
* `number_of_words_per_confirmed_step.csv` - Number of words uttered by user (includes all attempts)
   but only for the commands that were positively confirmed in the end. Empty if command
   was never positively confirmed.
* `pointing.csv` - Whether the user's pointing was relevant in inferring the command (1=yes, 0=no)
* `unique_id.csv`- Number of commands positiely confirmed within four tries, where the
   user used the unique ID to refer to an object or surface in the positively confirmed
   attempt. (unique ID is an element of the graphical visualization)