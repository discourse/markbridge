import { AsyncTransformOptions, TransformResult, ParseResult } from './types.js';
export { DiagnosticSeverity, ParseOptions, PreprocessedStyles, PreprocessorError, PreprocessorResult } from './types.js';
export { preprocessStyles } from './shared.js';
export { CompileResult, DiagnosticLabel, DiagnosticMessage, HoistedScript } from '@astrojs/compiler-binding';

declare function transform(input: string, options?: AsyncTransformOptions): Promise<TransformResult>;
declare function parse(input: string): Promise<ParseResult>;
declare function convertToTSX(_input: string): Promise<never>;

export { ParseResult, AsyncTransformOptions as TransformOptions, TransformResult, convertToTSX, parse, transform };
