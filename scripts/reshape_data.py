#! /usr/bin/env python
from numpy import mean
import sys

def header_string(condition, part):
    return '{}_{}'.format(condition, part)

def read_into_grid(fp):
    # Assumes a trailing comma and no blank data cells
    return [line.rstrip(',\n').split(',') for line in fp.readlines()]

def write_grid_to_csv(data, fp):
    # Uses comma as separator. Assumes no escaping is needed in the data to write.
    for row in data:
        text_row = [str(item) for item in row]
        text = ', '.join(text_row)
        line = '{}\n'.format(text)
        fp.write(line)

def reshape_csv(input_fp, output_fp, aggregate_fcn, data_start_row=2, num_data_rows=20):
    # Assumption: 15 columns for each robot, monitor, and oculus

    input_grid = read_into_grid(input_fp)
    #print 'input_grid', input_grid

    data_rows = range(data_start_row, num_data_rows + 1)
    print 'data_rows', data_rows

    conditions = ['baseline', 'monitor', 'oculus']
    parts = ['P1', 'P2']

    headers = ['participant_id'] + [
        header_string(condition, part)
        for condition in conditions
        for part in parts
    ]
    print 'headers', headers

    condition_start_cols = {'baseline': 1, 'monitor': 16, 'oculus': 31}
    part_cols = {'P1': range(0, 10), 'P2': range(10, 15)}

    # initialize output grid with headers and participant IDs
    # empty strings for data cells
    output_grid = [headers]
    #print 'output_grid',  output_grid

    for row_num in data_rows:
        row = input_grid[row_num]
        # print 'row', row
        # print 'len row', len(row)
        output_row = []
        participant_id = row[0]
        output_row.append(participant_id)
        for curr_condition in conditions:
            for curr_part in parts:
                # get column numbers for this part's data
                start = condition_start_cols[curr_condition]
                cols = [start + offset for offset in part_cols[curr_part]]
                # print 'cols', cols

                # grab the data and aggregate it
                curr_part_data = [
                    float(row[col])
                    for col in cols
                ]
                print 'data', curr_part_data
                aggregate_value = aggregate_fcn(curr_part_data)
                print 'aggregate', aggregate_value
                output_row.append(aggregate_value)
        output_grid.append(output_row)

    write_grid_to_csv(output_grid, output_fp)

if __name__ == '__main__':
    # Assumes unix file naming conventions (i.e. forward slash as separator)

    if len(sys.argv) < 2:
        print 'Usage: python reshape_data.py [transparency_analysis_repo_root_directory]\n' \
            'For example: python reshape_data.py /home/lrperlmu/trp_study/transparency_analysis'
        sys.exit()
    repo_dir = sys.argv[1]
    input_data_dir = 'data/original'
    output_data_dir = 'data/reshaped'

    input_filenames = ['attempt_times.csv']
    aggregation_functions = [mean]

    for filename, aggregation_fcn in zip(input_filenames, aggregation_functions):
        input_filename = repo_dir + '/' + input_data_dir + '/' + filename
        output_filename = repo_dir + '/' + output_data_dir + '/' + filename
        print 'opening', input_filename

        with open(input_filename, 'r') as input_fp, open(output_filename, 'w') as output_fp:
            reshape_csv(input_fp, output_fp, aggregation_fcn)
            print 'output file:', output_filename
