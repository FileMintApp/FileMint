#!/usr/bin/env python3
"""Offline regressions for SDK artifact verification; no apps, UI or signing."""
import copy
import sys
import unittest

sys.dont_write_bytecode = True
import verify_metadata as metadata


def summary(extra):
    return {'actionSummary': {'wrapper': {'otherParameterIdentifiers': ['location', 'content', *extra],
            'summaryString': {'parameterIdentifiers': ['name', 'template']}}}}


def when(extra):
    return {'whenClause': {'wrapper': {'condition': {'comparisonOperator': 2, 'parameterIdentifier': 'content',
        'value': {'enumeration': {'identifier': 'LauncherContentMode', 'value': 'text'}}},
        'when': summary([*extra, 'text']), 'otherwise': summary(extra)}}}


def fixture():
    cases = [{'isDefaultCase': False, 'value': {'array': {'values': [{'enumeration': {
        'identifier': 'LauncherSaveLocation', 'value': field}}]}}, 'configuration': when([field])}
        for field in ('folder', 'favorite')]
    cases.append({'isDefaultCase': True, 'configuration': when([])})
    return {'actions': {'OpenFileMintDraftIntent': {'openAppWhenRun': False, 'actionConfiguration': {
        'switchStatement': {'wrapper': {'parameterIdentifier': 'location', 'cases': cases}}}},
        'ShowFileMintQuickSearchIntent': {'openAppWhenRun': False, 'parameters': []}},
        'enums': [{'identifier': identifier, 'cases': [{'identifier': value} for value in values]}
            for identifier, values in [('LauncherSaveLocation', ('default', 'folder', 'favorite', 'ask')),
                                       ('LauncherContentMode', ('template', 'text', 'empty'))]]}


class MetadataTests(unittest.TestCase):
    def test_all_twelve_native_forms_and_search_are_checked(self):
        metadata.validate(fixture())

    def test_swift_case_name_cannot_replace_serialized_enum_id(self):
        value = fixture()
        condition = value['actions']['OpenFileMintDraftIntent']['actionConfiguration']['switchStatement']['wrapper']['cases'][0]['configuration']['whenClause']['wrapper']['condition']
        condition['value']['enumeration']['value'] = 'specifiedText'
        with self.assertRaisesRegex(metadata.MetadataError, 'serialized enum'):
            metadata.validate(value)

    def test_missing_text_and_inactive_location_fields_fail(self):
        for mutation in ('missing-text', 'inactive-folder'):
            value = fixture()
            default = value['actions']['OpenFileMintDraftIntent']['actionConfiguration']['switchStatement']['wrapper']['cases'][-1]['configuration']['whenClause']['wrapper']
            if mutation == 'missing-text':
                default['when']['actionSummary']['wrapper']['otherParameterIdentifiers'].remove('text')
            else:
                default['otherwise']['actionSummary']['wrapper']['otherParameterIdentifiers'].append('folder')
            with self.subTest(mutation=mutation), self.assertRaisesRegex(metadata.MetadataError, 'conditional fields'):
                metadata.validate(value)

    def test_query_injection_foreground_entry_and_unknown_schema_fail(self):
        for mutation in ('query', 'foreground', 'schema'):
            value = copy.deepcopy(fixture())
            if mutation == 'query':
                value['actions']['ShowFileMintQuickSearchIntent']['parameters'] = [{'name': 'query'}]
            elif mutation == 'foreground':
                value['actions']['OpenFileMintDraftIntent']['openAppWhenRun'] = True
            else:
                value['actions']['OpenFileMintDraftIntent']['actionConfiguration'] = {}
            with self.subTest(mutation=mutation), self.assertRaises(metadata.MetadataError):
                metadata.validate(value)


if __name__ == '__main__':
    unittest.main()
