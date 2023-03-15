# -*- coding:utf-8 -*-

import os
import sys

def warn(msg):
    sys.stderr.write('[to_table.py] ' + msg + '\n')

def error(msg):
    sys.stderr.write('[to_table.py] ' + msg + '\n')
    sys.exit(1)

def duration(val):
    unit = 's'
    if val > 999:
        val = val / 60
        unit = 'm'
    if val > 999:
        val = val / 60
        unit = 'h'
    if val > 999:
        val = val / 24
        unit = 'd'
    return val, unit

def bytes(val):
    unit = 'b'
    if val > 999:
        val = val / 1024
        unit = 'k'
    if val > 999:
        val = val / 1024
        unit = 'm'
    if val > 999:
        val = val / 1024
        unit = 'g'
    return val, unit

class Cell:
    def __init__(self, lines = None):
        self.lines = lines or []
        self.vals = []
        self.vals_fmt = {}
        self.vals_const = set()

    def append(self, line):
        self.lines.append(line)

    def empty(self):
        return len(self.lines) == 0

    def __str__(self):
        res = []
        for i in range(0, len(self.vals)):
            if self.vals[i] == None:
                continue
            x = str(self.vals[i])
            if self.vals_fmt.has_key(i):
                prefix, suffix = self.vals_fmt[i]
                x = prefix + x + suffix
            res.insert(0, x)
        return ' '.join(res)

class Table:
    def __init__(self, rows_notitle, cols_notitle):
        self.rows = {}
        self.row_names = []
        self.row_name_set = set()
        self.col_names = []
        self.col_name_set = set()
        self.rows_notitle = rows_notitle
        self.cols_notitle = cols_notitle

    def add_line(self, row_tags, row_notag, col_tags, col_notag, line):
        if row_tags:
            row_name = []
            for row_tag in row_tags:
                row_name.append((not row_notag and (row_tag + ':') or '') + line.tags[row_tag])
            row_name = ','.join(row_name)
        else:
            row_name = '*'

        if col_tags:
            col_name = []
            for col_tag in col_tags:
                col_name.append((not col_notag and (col_tag + ':') or '') + line.tags[col_tag])
            col_name = ','.join(col_name)
        else:
            col_name = '*'

        if not self.rows.has_key(row_name):
            self.rows[row_name] = {}
            if row_name not in self.row_name_set:
                self.row_name_set.add(row_name)
                self.row_names.append(row_name)
        row = self.rows[row_name]
        if not row.has_key(col_name):
            row[col_name] = Cell()
            if col_name not in self.col_name_set:
                self.col_name_set.add(col_name)
                self.col_names.append(col_name)
        row[col_name].append(line)

    def add_missed_cell(self):
        for row_name, row in self.rows.iteritems():
            for col_name in self.col_names:
                if not row.has_key(col_name):
                    row[col_name] = Cell()

    def _limit_rows(self, rows_limit):
        if rows_limit < 0 or rows_limit >= len(self.row_names):
            return
        del_cnt = len(self.row_names) - rows_limit
        del_rows = set(self.row_names[0: del_cnt])
        self.row_names = self.row_names[del_cnt:]
        for row_name in del_rows:
            self.row_name_set.remove(row_name)
            self.rows.pop(row_name)

    def _limit_cols(self, cols_limit):
        if cols_limit < 0 or cols_limit >= len(self.col_names):
            return
        del_cnt = len(self.col_names) - cols_limit
        del_cols = set(self.col_names[0: del_cnt])
        self.col_names = self.col_names[del_cnt:]
        for col_name in del_cols:
            self.col_name_set.remove(col_name)
            for row_name, row in self.rows.iteritems():
                row.pop(col_name)

    def limit(self, rows_limit, cols_limit):
        if rows_limit < 0:
            rows_limit = len(self.row_names)
        if cols_limit < 0 or cols_limit >= len(self.col_names):
            cols_limit = len(self.col_names)

        def del_empty_rows():
            del_rows = set()
            for row_name in self.row_names:
                row = self.rows[row_name]
                empty = True
                for col_name, cell in row.iteritems():
                    if not cell.empty():
                        empty = False
                        break
                if empty:
                    del_rows.add(row_name)

            for row_name in del_rows:
                self.row_names.remove(row_name)
                self.row_name_set.remove(row_name)
                self.rows.pop(row_name)

        def del_empty_cols():
            del_cols = set()
            for col_name in self.col_names:
                empty = True
                for row_name, row in self.rows.iteritems():
                    cell = row[col_name]
                    if not cell.empty():
                        empty = False
                        break
                if empty:
                    del_cols.add(col_name)

            for col_name in del_cols:
                self.col_names.remove(col_name)
                self.col_name_set.remove(col_name)
                for row_name, row in self.rows.iteritems():
                    row.pop(col_name)

        while len(self.col_names) > cols_limit or len(self.row_names) > rows_limit:
            if len(self.col_names) > cols_limit:
                self._limit_cols(len(self.col_names) - 1)
                del_empty_rows()
            if len(self.row_names) > rows_limit:
                self._limit_rows(len(self.row_names) - 1)
                del_empty_cols()

    def output(self, table_title):
        if self.cols_notitle:
            rows = []
        else:
            if self.rows_notitle:
                rows = [self.col_names]
            else:
                rows = [[table_title] + self.col_names]
        for row_name in self.row_names:
            row = self.rows[row_name]
            cols = []
            for col_name in self.col_names:
                cols.append(row[col_name])
            new_row = map(lambda x: str(x), cols)
            if not self.rows_notitle:
                new_row = [row_name] + new_row
            rows.append(new_row)
        return rows

class Line:
    def __init__(self, line, from_file, val, tags = []):
        self.val = long(val)
        self.tags = {}
        for tag in tags:
            fields = map(lambda x: x.strip(), tag.split(':'))
            if len(fields) != 2:
                #error('bad tag: ' + tag + ', in line: ' + line + ', in file: ' + from_file)
                continue
            self.tags[fields[0]] = fields[1]

    def map_tag(self, old_tag, new_tag):
        if self.tags.has_key(old_tag):
            self.tags[new_tag] = self.tags[old_tag]

    def map_val(self, tag, old_val, new_val):
        if self.tags.has_key(tag):
            val = self.tags[tag]
            if val.strip() == old_val.strip():
                val = new_val
            self.tags[tag] = val

    def map_tag_val(self, old_tag, old_val, new_tag, new_val):
        self.map_tag(old_tag, new_tag)
        self.map_val(old_tag, old_val, new_val)
        self.map_val(new_tag, old_val, new_val)

class PreExe:
    def __init__(self, op):
        if len(op) == 0:
            return
        tag_mapper = op.split('=')
        if len(tag_mapper) == 2:
            new_tag = tag_mapper[0].strip()
            old_tag = tag_mapper[1].strip()
            new_tag_val = new_tag.split('.')
            if len(new_tag_val) == 1:
                if len(old_tag.split('.')) != 1:
                    error('uneven pre-calculating op: ' + op)
                self.__call__ = lambda line: (line.map_tag(old_tag, new_tag) and None)
            else:
                if len(new_tag_val) != 2:
                    error('unknown pre-calculating op: ' + op)
                old_tag_val = old_tag.split('.')
                if len(old_tag_val) != 2:
                    error('uneven pre-calculating op: ' + op)
                self.__call__ = lambda line: (line.map_tag_val(old_tag_val[0], old_tag_val[1], new_tag_val[0], new_tag_val[1]) and None)
        else:
            error('unknown pre-calculating op: ' + op)

class ColsExp:
    def __init__(self, ops):
        self.limit = -1
        self.notag = False
        self.notitle = False

        segs = map(lambda x: x.strip(), ops.split('|'))

        if len(segs[0]) > 0:
            self.tags = map(lambda x: x.strip(), segs[0].split(','))
        else:
            self.tags = []

        segs = segs[1:]
        for seg in segs:
            if len(seg) == 0:
                continue
            if seg.startswith('limit(') and seg.endswith(')'):
                self.limit = int(seg[6:-1].strip())
                continue
            elif seg == 'notitle':
                self.notitle = True
                continue
            elif seg == 'notag':
                self.notag = True
                continue
            error('unknown cols op: ' + seg)

    def add_line(self, line, row_tags, row_notag, table):
        if len(self.tags) > 0:
            for tag in self.tags:
                if not line.tags.has_key(tag):
                    return
        table.add_line(row_tags, row_notag, self.tags, self.notag, line)

class RowsExp:
    def __init__(self, ops):
        self.limit = -1
        self.notag = False
        self.notitle = False

        segs = map(lambda x: x.strip(), ops.split('|'))

        if len(segs[0]) > 0:
            self.tags = map(lambda x: x.strip(), segs[0].split(','))
        else:
            self.tags = []

        segs = segs[1:]
        for seg in segs:
            if len(seg) == 0:
                continue
            if seg.startswith('limit(') and seg.endswith(')'):
                self.limit = int(seg[6:-1].strip())
                continue
            elif seg == 'notitle':
                self.notitle = True
                continue
            elif seg == 'notag':
                self.notag = True
                continue
            error('unknown rows op: ' + seg)

    def add_line(self, line, cols_exp, table):
        if len(self.tags) > 0:
            for tag in self.tags:
                if not line.tags.has_key(tag):
                    return
        cols_exp.add_line(line, self.tags, self.notag, table)

class CellExe:
    def __init__(self, ops):
        self._ops = []
        for op in map(lambda x: x.strip(), ops.split('|')):
            self._ops.append(self._parse_op(op))

    def _parse_op(self, op):
        def add_unit(cell, caster):
            for i in range(0, len(cell.vals)):
                val, unit = caster(cell.vals[i])
                cell.vals[i] = val
                if i in cell.vals_const:
                    continue
                prefix, suffix = '', ''
                if cell.vals_fmt.has_key(i):
                    prefix, suffix = cell.vals_fmt[i]
                cell.vals_fmt[i] = (prefix, suffix and (unit + ' ' + suffix) or unit)

        if op.startswith('limit(') and op.endswith(')'):
            limit = int(op[6:-1].strip())
            def limiter(row_name, col_name, cell):
                cell.lines = cell.lines[-limit:]
            return limiter
        if op == 'avg':
            def avg(row_name, col_name, cell):
                vals = map(lambda line: long(line.val), cell.lines)
                val = None
                if len(vals) > 0:
                    val = sum(vals) / len(vals)
                cell.vals.append(val)
            return avg
        if op == '~':
            def mp(row_name, col_name, cell):
                if len(cell.vals) == 0:
                    error('can\'t exe `~`, cause no value calcauted before')
                val = cell.vals[0]
                if val == None:
                    return
                x = 0
                for line in cell.lines:
                    x = max(x, abs(line.val - val))
                if x == 0:
                    return
                cell.vals.append(x)
                cell.vals_fmt[len(cell.vals) - 1] = ('-+', '')
            return mp
        if op == 'cnt':
            def cnt(row_name, col_name, cell):
                if len(cell.lines) == 0:
                    return
                cell.vals.append(len(cell.lines))
                cell.vals_fmt[len(cell.vals) - 1] = ('', ')')
                cell.vals_const.add(len(cell.vals) - 1)
            return cnt
        if op == 'duration':
            return lambda row_name, col_name, cell: add_unit(cell, duration)
        if op == 'bytes':
            return lambda row_name, col_name, cell: add_unit(cell, bytes)

        error('unknown cell op: ' + op)

    def __call__(self, row_name, col_name, cell):
        for op in self._ops:
            op(row_name, col_name, cell)

class Render:
    def __init__(self, ops_str):
        self._pre_exe = []
        self._cell = None
        self._rows = None
        self._cols = None
        self._rendered = False

        ops = map(lambda x: x.strip(), ops_str.split(';'))
        for opt in ops:
            if opt.startswith('rows:'):
                if self._rows:
                    error('too much rows definitions: ' + opt)
                self._rows = RowsExp(opt[5:].strip())
            elif opt.startswith('cols:'):
                if self._cols:
                    error('too much cols definitions: ' + opt)
                self._cols = ColsExp(opt[5:].strip())
            elif opt.startswith('cell:'):
                if self._cell:
                    error('too much cell definitions: ' + opt)
                self._cell = CellExe(opt[5:].strip())
            else:
                for seg in map(lambda x: x.strip(), opt.split('|')):
                    self._pre_exe.append(PreExe(seg))

        if not self._rows:
            error('no rows definitions: ' + ops_str)
        if not self._cols:
            error('no cols definitions: ' + ops_str)
        if not self._cell:
            error('no cell definitions: ' + ops_str)

        self._table = Table(self._rows.notitle, self._cols.notitle)

    def add_line(self, line):
        assert not self._rendered, 'can\'t add line to Render when it\'s already rendered.'
        for op in self._pre_exe:
            line = op(line) or line
        self._rows.add_line(line, self._cols, self._table)

    def render(self):
        self._table.add_missed_cell()
        self._table.limit(self._rows.limit, self._cols.limit)
        for row_name, row in self._table.rows.iteritems():
            for col_name, cell in row.iteritems():
                self._cell(row_name, col_name, cell)
                row[col_name] = cell
        self._rendered = True

    def get_table(self):
        return self._table

def parse_line(line, from_file):
    segs = map(lambda x: x.strip(), line.split())
    if len(segs) == 2:
        return Line(line, from_file, segs[0], map(lambda x: x.strip(), segs[1].split(',')))
    elif len(segs) == 1:
        return Line(line, from_file, line)
    elif len(segs) == 0:
        return Line(line, from_file, 0)
    else:
        error('bad line: ' + line + ', in file: ' + from_file)

# TODO: slow in reading big file
def read_files(tail_cnt, paths):
    total = []
    for path in paths:
        with open(path) as file:
            lines = file.readlines()[-tail_cnt:]
            lines = map(lambda x: x[:-1], lines)
            lines = filter(lambda x: x, lines)
            lines = map(lambda x: parse_line(x, path), lines)
            total += lines
    return total

def padding_table(table, cols_notitle):
    if not cols_notitle:
        widths = []
        for i in range(1, len(table)):
            cols = table[i]
            if len(cols) == 0:
                error('bad table: ' + str(table))
            tags = cols[0]
            fields = tags.split(',')
            while len(widths) < len(fields):
                widths.append(0)
            for i in range(0, len(fields)):
                field = fields[i]
                widths[i] = max(widths[i], len(field))
        for cols in table:
            tags = cols[0]
            fields = tags.split(',')
            for i in range(0, len(fields)):
                field = fields[i]
                field = field + (' ' * (widths[i] - len(field)))
                fields[i] = field
            cols[0] = ' '.join(fields)

    widths = []
    for cols in table:
        for cell in cols:
            widths.append(0)
        break
    for cols in table:
        for i in range(0, len(cols)):
            cell = cols[i]
            widths[i] = max(widths[i], len(cell))
    for i in range(0, len(table)):
        cols = table[i]
        for j in range(0, len(cols)):
            cell = cols[j]
            left_pad = (j != 0 and '' or '')
            if i == 0 and j == 0:
                cols[j] = cell + ' ' * (widths[j] - len(cell)) + ' '
            else:
                cols[j] = left_pad + ' ' * (widths[j] - len(cell)) + cell + ' '

def align_cells(table):
    for i in range(0, len(table)):
        cols = table[i]
        for j in range(0, len(cols)):
            if i == 0:
                if j != 0:
                    cols[j] = ' ' + cols[j]
                else:
                    cols[j] = cols[j] + ' '
                continue
            cell = cols[j]
            width = len(cell)
            fields = cell.split()
            if len(fields) == 1:
                continue

            # Something wrong here, this is a workaroud, need further fix
            if len(fields) == 0:
                cols[j] = ' ' + cols[j]
                continue

            aligned = ' '.join(fields[0:-1])
            padding = width - len(aligned) - len(fields[-1]) - 2 + 1
            j0_pad = ' '
            if j == 0:
                j0_pad = ''
            cols[j] = ' ' + aligned + ' ' * padding + fields[-1] + ' '

def to_table(table_title, render_str, tail_cnt, paths):
    lines = read_files(tail_cnt, paths)
    render = Render(render_str)
    for line in lines:
        render.add_line(line)
    try:
        render.render()
        table = render.get_table().output(table_title)
        if len(table) == 1:
            return
        padding_table(table, render._cols.notitle)
        align_cells(table)
        for cols in table:
            print '|'.join(cols + [''])
    except Exception, e:
        print '{\n' + str(lines) + '}\n'
        raise e

# TODO: tag sorting: asc/desc
if __name__ == '__main__':
    if len(sys.argv) < 5:
        error('usage: <bin> table_title, render_str, tail_limit_on_each_file, data_file1, [data_file2] [...]')
    to_table(sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4:])
