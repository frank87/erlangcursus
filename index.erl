-module(index).
-export([get_file_contents/1,show_file_contents/1, index_file/1, 
	 joinLineNo/2, show_index/1, removeCommon/2, line_cnt/1 ]).

% Used to read a file into a list of lines.
% Example files available in:
%   gettysburg-address.txt (short)
%   dickens-christmas.txt  (long)
  

% Get the contents of a text file into a list of lines.
% Each line has its trailing newline removed.

get_file_contents(Name) ->
    {ok,File} = file:open(Name,[read]),
    Rev = get_all_lines(File,[]),
lists:reverse(Rev).

% Auxiliary function for get_file_contents.
% Not exported.

get_all_lines(File,Partial) ->
    case io:get_line(File,"") of
        eof -> file:close(File),
               Partial;
        Line -> {Strip,_} = lists:split(length(Line)-1,Line),
                get_all_lines(File,[Strip|Partial])
    end.

% Show the contents of a list of strings.
% Can be used to check the results of calling get_file_contents.

show_file_contents([L|Ls]) ->
    io:format("~s~n",[L]),
    show_file_contents(Ls);
 show_file_contents([]) ->
    ok.    
     
% Tuple for words:
% { Normalised word, original word, line number }

% output result: ignore normalised version on first tuple-location.
show_index( [{_, Word, Lines }| Ls ]) ->
	io:format("~s:~lp~n", [Word, Lines] ),
	show_index(Ls);
show_index([]) ->
	ok.

% main entry point: Loads file with get_file_contents.
% splitwords splits the lines, and normalises words
% sortwords sorts
% foldl) lineList joins duplicates
index_file(Name) -> lists:foldl( fun lineList/2, [],
		      sortwords(
		        splitwords( get_file_contents(Name), 1 )
		      )
		    ).

% comp( Wt1, Wt2, Default )
% compare 2 words lexicograficaly : returns if Wt1 should be behind Wt2
% Wt1 : first word tuple: { Normalised word, Word, lineno }
% Wt2 : first word tuple: { Normalised word, Word, lineno }
% Default : return value is Wt1 and Wt2 are equal. ( Used to sort on 
% 	line-numbers, the next step expects them sorted )
comp( [A|As], [A|Bs], Default ) 
		-> comp(As,Bs, Default );
comp( [A|_], [B|_], _ ) 
		-> (A > B);
comp( [], [_|_], _  ) 
		-> false;			% shortest first
comp( [_|_] , [], _ ) -> true;
comp( _, _, Default )
		-> Default. 	% when equal, return default


% lineList( Wt, Wts ) -> Rts
% 	Wt  : word tuple
% 	Wts : list of word tuples
% 	Rts : list of word tuples with the line number replaces with a list of 
% 		line-numbers.
% Adds next tuple in front of the accumulator, joins it with the first record
% if the normalised form is equal.
lineList( { An, A, N }, [] ) -> [ { An, A, [N] } ];
lineList( { An, _A, N }, [{ An, B, Ns }|Bs] ) -> 
		[{ An, B, joinLineNo( N, Ns ) }| Bs ];
lineList( { An, A, N }, [{ Bn, B, Ns }|Bs] ) -> 
		[ { An, A, [N] }|[{ Bn, B, Ns }| Bs ]].

% sortwords( X )
% 	X : list of word tuples
% 	result: sorted list of word tuples
% Sort function is based on normalised words, and line number: the end-result
% should be sorted by line-number.
sortwords(X) -> lists:sort( 
			fun( { A, _, La }, { B, _, Lb } ) -> 
					comp( A, B, La > Lb )
			end,
			X
			).

% joinLineNo( N, Ns )
% 	N : number to add
% 	Ns: list of number
% 	result: List of unique numbers with tuples representing ranges: 
% 		{1,5} = 1,2,3,4,5
% I think tuples representing single numbers are ugly, so I didn't make tuples 
% like { 2,2 }. Numbers should be sorted before adding.
% first: adding to range-tuple
joinLineNo( N, [{N,_}|_] = L ) -> L; % don't add duplicates
joinLineNo( N, [{_,N}|_] = L ) -> L; % for both sorting directions
joinLineNo( N, [ {L0, L1 } | Ls ] = L ) ->
	case { L0 - 1, L1 + 1 } of
		{ N, _ } -> [ {N, L1} | Ls ];	% paste onto tuple
		{ _, N } -> [ {L0, N} | Ls ];	% both directions
		_	-> [ N| L ]		% there is a gap: add number
	end;
% front of list is a number:
joinLineNo( N, [N|_] = L ) -> L;    % no duplicates
joinLineNo( N, [L|Ls] = Lt) -> 
	case { L - 1, L + 1 } of
		{ N, _ } -> [ {N,L} | Ls ];	% create tuple
		{ _, N } -> [ {L,N} | Ls ];	% both directions
		_	-> [ N|Lt ]	% just add
	end;
joinLineNo( N, [] ) -> [ N ].

% splitwords(Ls, N )
% 	Ls	:	List of text lines
% 	N	:	Linenumber of head
%	returns	:	list of word-tuples (described above).
splitwords([], _) -> [];
splitwords([L|Ls], N ) -> 
	lists:append( lists:map( fun (X) -> { norm(X), X, N } end, 
			         string:tokens( L, " ()?:`.,!;-\\" ) ),
		      splitwords( Ls, N + 1 ) ).

% norm( X )
% 	X	:	word to normalise
% 	returns	:	uppercase version of X
% Kan be extented to remove uninteresting tails.
norm( X ) -> string:to_upper(X).


% overly common words can be filtered by counting the number of instances in 
% JoinLineNo. But it's probably easier to do postprocessing:
% removeCommon( Ws, N )
% 	Ws	:	word list
% 	N	:	max number of occurences allowed
removeCommon( Ws, N ) ->
	lists:filter( fun ( { _, _, Ls } ) -> line_cnt(Ls) < N end,
		      Ws ).

line_cnt( [] ) -> 0;
line_cnt( [{ A, B }|Ls] ) -> 1 + B - A + line_cnt(Ls);
line_cnt( [_|Ls] ) -> 1 + line_cnt(Ls).

% test for example:
% index:show_index(index:removeCommon(index:index_file( "gettysburg-address.txt" ), 3)).
