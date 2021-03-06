%%%-------------------------------------------------------------------
%%% File:      erlyjs_suite.erl
%%% @author    Roberto Saccon <rsaccon@gmail.com> [http://rsaccon.com]
%%% @copyright 2007 Roberto Saccon
%%% @doc       ErlyJS regression test suite
%%% @end
%%%
%%% The MIT License
%%%
%%% Copyright (c) 2007 Roberto Saccon
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%%
%%% @since 2007-12-14 by Roberto Saccon
%%%-------------------------------------------------------------------
-module(erlyjs_testsuite).
-author('rsaccon@gmail.com').

%% API
-export([run/0, run_group/1, run/1]).

%%====================================================================
%% API
%%====================================================================

%%--------------------------------------------------------------------
%% @spec () -> Ast::tuple()
%% @doc
%% @end 
%%--------------------------------------------------------------------
run() ->    
    run2(src_test_dir()).   


run_group(Group) -> 
   run2(filename:join([src_test_dir(), Group])).   
         
    
run(Name) ->
    case recreate_scanner_parser() of
        ok ->
            case make:all([load]) of
                up_to_date ->
                    case fold_tests("^" ++ Name ++ "\.js$", true, src_test_dir()) of
                        {0, _} -> {error, "Test not found: " ++ Name ++ ".js"};
                        {1, []} -> {ok, "Regression test passed"};
                        {1, Errs} -> {error, Errs};
                        {_, _} -> {error, "Testsuite requires different filename for each test"}
                    end;
                _ ->
                    {error, "ErlyJS library compilation failed"}
            end;
        Err ->
            Err
    end.
 
 
	
%%====================================================================
%% Internal functions
%%====================================================================
  
run2(Dir) ->    
    case recreate_scanner_parser() of
        ok ->                                               
            case fold_tests("^[^(SKIP_)].+\.js$", false, Dir) of
                {N, []}->
                    Msg = lists:concat(["All ", N, " regression tests passed"]),
                    {ok, Msg};
                {_, Errs} -> 
                    {error, Errs}
            end;
        Err ->
            Err
    end.        
    
    
recreate_scanner_parser() ->
    crypto:start(),
    case recreate(erlyjs:scanner_src(),  scanner) of
        ok ->
            recreate(erlyjs:parser_src(), parser);
        Err ->
            Err
    end.
    
    
recreate(File, What) ->
    Func = list_to_atom(lists:concat(['create_', What])),
    case file:read_file(File) of
        {ok, Data} ->
            CheckSum = binary_to_list(crypto:sha(Data)),
            Key = list_to_atom(lists:concat([erlyjs, Func, '_checksum'])),
            case get(Key) of
                CheckSum ->
                    ok;
                _ ->
                    erlyjs:Func(),
                    put(Key, CheckSum),
                    io:format("Recompiling: ~p ...~n",[What]),
                    ok
            end;            
        _ ->
            erlyjs:Func(),
            recreate(File, What)
    end.
            

fold_tests(RegExp, Verbose, Dir) ->
    filelib:fold_files(Dir, RegExp, true, 
        fun
            (File, {AccCount, AccErrs}) ->
                case test(File, Verbose) of
                    ok -> 
                        {AccCount + 1, AccErrs};
                    {error, Reason} -> 
                        {AccCount + 1, [{File, Reason} | AccErrs]}
                end
        end, {0, []}).    

    
test(File, Verbose) ->
	Module = "js_" ++ filename:rootname(filename:basename(File)),
	io:format("Compiling: ~p ... ",[Module]),  
	Options = [{force_recompile, true}, {verbose, Verbose}],
	case erlyjs_compiler:compile(File, Module, Options) of
	    ok ->
	        M = list_to_atom(Module),
	        Expected = M:js_test_ok(),
	        Args = M:js_test_args(),
	        M:jsinit(),
	        Result = case catch apply(M, js_test, Args) of
	            Expected ->
	                io:format("ok ~n"),   
	                ok;
	            Val when is_number(Val) ->
	                case Expected == Val of
        	            true ->
        	                io:format("ok ~n"),  
        	                ok;
        	            _ ->
        	                io:format("~n"),
        	                {error, "test failed: " ++ Module ++ " Result: " ++ Val}
        	        end;
	            Other ->
	                io:format("~n"),
	                {error, "test failed: " ++ Module ++ " Result: " ++ Other}
	        end,
	        M:jsreset(),
	        Result;               
	    Err ->
	       Err 
	end.
	
	
src_test_dir() ->
    {file, Ebin} = code:is_loaded(?MODULE),
    filename:join([filename:dirname(filename:dirname(Ebin)), "src", "tests"]).