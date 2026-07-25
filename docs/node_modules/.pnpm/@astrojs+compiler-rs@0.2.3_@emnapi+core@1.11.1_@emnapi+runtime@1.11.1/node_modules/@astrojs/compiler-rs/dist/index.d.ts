import { TransformOptions, TransformResult, ParseResult, ConvertToTSXOptions } from './types.js';
export { DiagnosticSeverity, ParseOptions, PreprocessedStyles, PreprocessorError, PreprocessorResult } from './types.js';
export { preprocessStyles } from './shared.js';
export { CompileResult, DiagnosticLabel, DiagnosticMessage, HoistedScript } from '@astrojs/compiler-binding';

declare function transform(input: string, options?: TransformOptions): TransformResult;
declare function parse(input: string): ParseResult;
declare function convertToTSX(_input: string, _options: ConvertToTSXOptions): never;

export { ParseResult, TransformOptions, TransformResult, convertToTSX, parse, transform };
