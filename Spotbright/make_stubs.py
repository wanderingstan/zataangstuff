import os, sys
import re

def parse_signature(sig):
    sig = re.compile(r'; *$').sub('', sig)
    sig = re.compile(r'^[^\(]*').sub('', sig)

    ret = { 'args' : [] }
    for c in re.compile(r'\s+').split(sig):
        r = re.compile(r'^\(([^\)]+)\)')
        m = r.match(c)
        if m:
            ret['return_type'] = m.group(1)
            c = r.sub('', c)

        r = re.compile(r'(?P<arg_name>[^:]+):\((?P<type>[^\)]+)\)\s*(?P<arg_id>.*)')
        m = r.match(c)
        if m:
            d = m.groupdict()
            ret['args'].append(d)
        else:
            ret['args'].append({ 'arg_name' : c, 'type' : '', 'arg_id': '' })

    return ret

def make_protocol_signatures(sel):
    sel_string = \
            '- (%s) %s_' % (sel['return_type'], sel['prefix'])
    components = []
    for arg in sel['args']:
        if arg['arg_id'] == '':
            components.append(arg['arg_name'])
        else:
            components.append('%s:(%s)%s' % (arg['arg_name'], arg['type'], arg['arg_id']))

    sel_string += ' '.join(components) + ';'

    return sel_string

def make_inject_code(sel):
    sel['func_name'] = get_func_name(sel)
    sel['selector'] = ':'.join(arg['arg_name'] for arg in sel['args'])
    if len(sel['args']) > 0 and sel['args'][0]['arg_id'] != '':
        sel['selector'] += ':'

    s = '''MyRename(YES, "%(class_name)s", @selector(%(selector)s), (IMP)&%(func_name)s);''' % sel
    return s

def get_func_name(sel):
    return '__' + \
            sel['class_name'] + '_' + \
            '_'.join(arg['arg_name'] for arg in sel['args'])

def make_stub_function(sel):
    sel['func_name']  = get_func_name(sel)
    sel['short_func_name'] = sel['args'][0]['arg_name']

    sel['args_string'] = '%s *self, SEL sel' % (sel['class_name'])
    if len(sel['args']) > 0 and sel['args'][0]['arg_id'] != '':
        sel['args_string'] = sel['args_string'] + ', ' + \
          ', '.join(' '.join([arg['type'], arg['arg_id']]) for arg in sel['args'] )

    components = []
    for arg in sel['args']:
        if arg['arg_id'] == '':
            components.append(arg['arg_name'])
        else:
            components.append(':'.join([arg['arg_name'], arg['arg_id']]))

    sel['sel_string'] = ' '.join(components)

    if sel['return_type'] == 'void':
        sel['ret_statement'] = ''
    else:
        sel['ret_statement'] = 'return '
    s = '''
static %(return_type)s %(func_name)s(%(args_string)s) {
    // NSLog(@"%(short_func_name)s called");
    %(ret_statement)s[self %(prefix)s_%(sel_string)s];
}
    ''' % sel
    return s

def get_all_info(class_name, sig, prefix):
    info = parse_signature(sig)
    info['class_name'] = class_name
    info['prefix'] = prefix

    return info

prefix = 'spotbright'
sigs = {}
sigs['SBSearchController'] = '''
- (void)setSearchView:(id)fp8;
- (void)updateSearchOrdering;
- (void)resetClearSearchTimer;
- (void)startClearSearchTimer;
- (void)_updateClearSearchTimerFireDate;
- (void)_clearSearchTimerFired;
- (BOOL)hasQueryString;
- (BOOL)hasSearchResults;
- (void)searchBarTextDidBeginEditing:(id)fp8;
- (void)searchBarTextDidEndEditing:(id)fp8;
- (void)searchBar:(id)fp8 textDidChange:(id)fp12;
- (void)searchBarSearchButtonClicked:(id)fp8;
- (BOOL)_sectionIsApp:(int *)fp8 appOffset:(int *)fp12;
- (int)tableView:(id)fp8 numberOfRowsInSection:(int)fp12;
- (int)numberOfSectionsInTableView:(id)fp8;
- (id)tableView:(id)fp8 cellForRowAtIndexPath:(id)fp12;
- (id)_stringFromDate:(id)fp8;
- (void)tableView:(id)fp8 didSelectRowAtIndexPath:(id)fp12;
- (void)_deselect;
- (void)tableView:(id)fp8 willDisplayCell:(id)fp12 forRowAtIndexPath:(id)fp16;
- (id)tableView:(id)fp8 viewForHeaderInSection:(int)fp12;
- (void)scrollViewDidScroll:(id)fp8;
- (void)updateTableContents;
- (void)searchDaemonQuery:(id)fp8 addedResults:(id)fp12;
- (void)searchDaemonQuery:(id)fp8 encounteredError:(id)fp12;
- (void)searchDaemonQueryCompleted:(id)fp8;
- (BOOL)_shouldDisplayApplicationSearchResults;
- (void)_promoteAccumulatedResults;
- (void)_releaseAccumulatingResultGroups;
- (void)_releaseResultGroups;
- (void)_updateSectionToGroupMap;
- (id)_groupForSection:(int)fp8;
- (int)_groupIndexForSection:(int)fp8;
- (int)_resultSectionCount;
- (id)_launchingURLForResult:(id)fp8 withDisplayIdentifier:(id)fp12;
- (void)_updateApplicationSearchResults;
- (id)_imageForDomain:(int)fp8 andDisplayID:(id)fp12;
- (id)_imageForDisplayIdentifier:(id)fp8;
- (void)clearSearchResults;
- (id)searchView;
'''
sigs['SBSearchTableViewCell'] = '''
- (void)setEdgeInset:(float)fp8;
- (void)setSectionHeaderWidth:(float)fp8;
- (void)setFirstInSection:(BOOL)fp8;
- (void)setFirstInTableView:(BOOL)fp8;
- (void)setUsesAlternateBackgroundColor:(BOOL)fp8;
- (void)setBadged:(BOOL)fp8;
- (void)setSubtitleComponents:(id)fp8;
'''
sigs['SBUIController'] = '''
- (void)activateApplicationAnimated:(id)fp8;
'''
sigs['SBSearchQuery'] = '''
- (id)initWithSearchString:(id)fp8 andDomainsVector:(char *)fp12 vectorCount:(int)fp16;
- (id)initWithSearchString:(id)fp8 forSearchDomains:(id)fp12;
- (id)initWithSearchString:(id)fp8;
'''
del sigs['SBSearchController']
del sigs['SBSearchTableViewCell']
del sigs['SBUIController']

infos = []
for class_name, method_string in sigs.iteritems():
    for m in method_string.split('\n'):
        if re.compile(r'^\s*$').match(m):
            continue
        infos.append(get_all_info(class_name, m, prefix))

print ''.join(make_stub_function(info) for info in infos)
print '@protocol BlahBlah'
print '\n'.join(make_protocol_signatures(info) for info in infos)
print '@end'
print '\n'
print '\n'.join(make_inject_code(info) for info in infos)
