#!/usr/bin/env python3
"""Verify the SDK-emitted native parameter contract, without executing an app."""
import argparse
import json
from pathlib import Path


class MetadataError(ValueError):
    pass


def references(value):
    if isinstance(value, dict):
        if 'enumeration' in value:
            yield value['enumeration']
        for child in value.values():
            yield from references(child)
    elif isinstance(value, list):
        for child in value:
            yield from references(child)


def configured_fields(configuration, values):
    if 'actionSummary' in configuration:
        summary = configuration['actionSummary']['wrapper']
        return set(summary['otherParameterIdentifiers']) | set(summary['summaryString']['parameterIdentifiers'])
    if 'switchStatement' in configuration:
        switch = configuration['switchStatement']['wrapper']
        default = None
        for case in switch['cases']:
            if case.get('isDefaultCase'):
                default = case['configuration']
            elif any(item['enumeration']['value'] == values[switch['parameterIdentifier']]
                     for item in case['value']['array']['values']):
                return configured_fields(case['configuration'], values)
        if default is not None:
            return configured_fields(default, values)
    if 'whenClause' in configuration:
        when = configuration['whenClause']['wrapper']
        condition = when['condition']
        if condition['comparisonOperator'] != 2:
            raise MetadataError('Unsupported SDK comparison operator')
        expected = condition['value']['enumeration']['value']
        branch = 'when' if values[condition['parameterIdentifier']] == expected else 'otherwise'
        return configured_fields(when[branch], values)
    raise MetadataError('Unsupported SDK parameter configuration')


def validate(value):
    try:
        actions = value['actions']
        drafts = [a for key, a in actions.items() if key.endswith('OpenFileMintDraftIntent')]
        searches = [a for key, a in actions.items() if key.endswith('ShowFileMintQuickSearchIntent')]
        if len(drafts) != 1 or len(searches) != 1:
            raise MetadataError('Expected both production Intents exactly once')
        draft = drafts[0]
        enum_cases = {enum['identifier']: {case['identifier'] for case in enum['cases']} for enum in value['enums']}
        for reference in references(draft['actionConfiguration']):
            if reference['value'] not in enum_cases[reference['identifier']]:
                raise MetadataError('Summary condition differs from the serialized enum identifier')
        for location in ('default', 'folder', 'favorite', 'ask'):
            for content in ('template', 'text', 'empty'):
                expected = {'name', 'template', 'location', 'content'}
                if location in ('folder', 'favorite'):
                    expected.add(location)
                if content == 'text':
                    expected.add('text')
                actual = configured_fields(draft['actionConfiguration'], {'location': location, 'content': content})
                if actual != expected:
                    raise MetadataError(f'Incorrect conditional fields: {location}/{content}')
        if searches[0]['parameters']:
            raise MetadataError('External search must not overwrite a query through parameters')
        if draft['openAppWhenRun'] or searches[0]['openAppWhenRun']:
            raise MetadataError('Background host entry must precede explicit native presentation')
    except (KeyError, TypeError) as error:
        raise MetadataError('Unsupported or incomplete SDK metadata') from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('metadata', type=Path)
    args = parser.parse_args()
    if args.metadata.stat().st_size > 16 * 1024 * 1024:
        raise MetadataError('SDK metadata exceeds the verification limit')
    validate(json.loads(args.metadata.read_text()))
    print('PASS production Intents metadata: enum references, all 12 conditional forms, no-argument search and host execution')


if __name__ == '__main__':
    main()
