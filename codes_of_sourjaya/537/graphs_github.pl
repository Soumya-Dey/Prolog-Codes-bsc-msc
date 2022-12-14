:- use_module(library(apply)).
:- use_module(library(apply_macros)).
:- use_module(library(assoc)).
:- use_module(library(ordsets)).
:- use_module(library(yall)).

% 6.01 (***) Conversions

% Write predicates to convert between the different graph representations. With
% these predicates, all representations are equivalent; i.e. for the following
% problems you can always freely pick the most convenient form. The reason this
% problem is rated (***) is not because it's particularly difficult, but because
% it's a lot of work to deal with all the special cases.

% Here is a brief summary of the abbreviations Im using for this task, and
% three examples of each representation (first is undirected, second is
% directed, third is labelled).

% Figure for undirected graph examples:
% https://sites.google.com/site/prologsite/_/rsrc/1264948248705/prolog-problems/6/graph1.gif

% Figure for directed graph examples:
% https://sites.google.com/site/prologsite/_/rsrc/1264948667063/prolog-problems/6/graph2.gif

% Figure for labelled graph examples:
% https://sites.google.com/site/prologsite/prolog-problems/6/graph3.gif

% ec: edge-clause form, e.g.
%     [edge(h, g), edge(k, f), edge(f, b), edge(b, c), edge(c, f)]
%     [arc(s, u), arc(u, r), arc(s, r), arc(u, s), arc(v, u)]
%     [arc(m, q, 7), arc(p, q, 9), arc(p, m, 5)]

% gt: graph-term form, e.g.
%     graph([b, c, d, f, g, h, k],
%           [e(b, c), e(b, f), e(c, f), e(f, k), e(g, h)])
%     digraph([r, s, t, u, v], [a(s, r), a(s, u), a(u, r), a(u, s), a(v, u)])
%     digraph([k, m, p, q], [a(m, q, 7), a(p, m, 5), a(p, q, 9)])

% al: adjacency-list form, e.g.
%     [n(b, [c, f]), n(c, [b, f]), n(d, []), n(f, [b, c, k]), n(g, [h]),
%      n(h, [g]), n(k, [f])]
%     [n(r, []), n(s, [r, u]), n(t, []), n(u, [r]), n(v, [u])]
%     [n(k, []), n(m, [q/7]), n(p, [m/5, q/9]), n(q, [])]

% hf: human-friendly form, e.g.
%     [b-c, f-c, g-h, d, f-b, k-f, h-g]
%     [s > r, t, u > r, s > u, u > s, v > u]
%     [p>q/9, m>q/7, k, p>m/5]

% Convert between edge-clause and graph-term forms in either flow order.
% Edge-clause form cannot encode isolated nodes, so these are lost in the (?, +)
% flow order.
ec_gt(ECs, G) :- nonvar(ECs), !, ec_to_gt(ECs, G, _).
ec_gt(ECs, G) :- graph_term(G, _, Es, _), maplist(edge_terms, Es, ECs, _, _).

% Convert edge-clause to graph-term.
ec_to_gt([], G, D) :- (var(D) -> D=u; true), graph_term(G, [], [], D).
ec_to_gt([Edge|Edges], G, D) :-
  (functor(Edge, arc, _) -> D=d; D=u),
  ec_to_gt(Edges, G1, D),
  graph_term(G1, N1, E1, _),
  edge_terms(E, Edge, _, Ns),
  ord_add_all(N1, Ns, N2),
  ord_union(E1, [E], E2),
  graph_term(G, N2, E2, D).

ord_add_all(S1, Es, S2) :- sort(Es, SEs), ord_union(S1, SEs, S2).

% Convert between (di)graphs and their component terms. The final u/d term flags
% directedness (necessary when using in the construction flow order).
graph_term(graph(Ns, Es),   Ns, Es, u).
graph_term(digraph(Ns, As), Ns, As, d).

% Convert between e/a terms, edge/arc terms, "human-friendly" terms and node
% lists.
edge_terms(e(A, B, C), edge(A, B, C), A-B/C, [A, B]).
edge_terms(e(A, B),    edge(A, B),    A-B,   [A, B]).
edge_terms(a(A, B, C), arc(A, B, C),  A>B/C, [A, B]).
edge_terms(a(A, B),    arc(A, B),     A>B,   [A, B]).

% Convert between graph-term and adjacency-list forms in either flow order.
% Note that adjacency-list form doesn't distinguish between graphs and digraphs,
% so the (?, +) flow order always returns a digraph.
gt_al(G, AL) :- nonvar(G), !, gt_to_al(G, AL).
gt_al(G, AL) :- al_to_gt(AL, G).

% Convert graph-term to adjacency-list.
gt_to_al(G, AL) :-
  graph_term(G, Ns, Es, _),
  maplist([X, Y]>>(Y = X-[]), Ns, Empties),
  list_to_assoc(Empties, Assoc),
  expand_edges(Es, As),
  foldl([P>Q, A, A1]>>(get_assoc(P, A, V), put_assoc(P, A, [Q|V], A1)),
    As, Assoc, Assoc1),
  assoc_to_list(Assoc1, Pairs),
  maplist([K-V, N]>>(msort(V, V1), N = n(K, V1)), Pairs, AL).

% Convert e/a terms to human-friendly arc terms, with edges expanded to two
% arc terms rather than the corresponding -/2 functor.
expand_edges([], []).
expand_edges([E|Es], A) :- edge_arcs(E, A, A1), expand_edges(Es, A1).

% Convert an e/a term to a difference list of human-friendly arc terms, with
% edges being expanded to two arc terms.
edge_arcs(e(A, B),    [A>B, B>A|X],     X).
edge_arcs(e(A, B, C), [A>B/C, B>A/C|X], X).
edge_arcs(a(A, B),    [A>B|X],          X).
edge_arcs(a(A, B, C), [A>B/C|X],        X).

% Convert adjacency-list to graph-term. The adjacency-list form doesn't
% distinguish between graphs and digraphs, so we always return a digraph.
al_to_gt([], digraph([], [])).
al_to_gt([n(N, Neighbours)|Ns], digraph(GNs_, GEs_)) :-
  al_to_gt(Ns, digraph(GNs, GEs)),
  ord_union(GNs, [N], GNs_),
  maplist({N}/[Neighbour, A]>>edge_terms(A, _, N>Neighbour, _), Neighbours, As),
  ord_union(GEs, As, GEs_).

% Convert between edge-clause and adjacency-list forms in either flow order.
% Note that isolated nodes are lost in the (?, +) flow order as edge-clause form
% has no way to represent them, and arcs are always used, as adjacency-list form
% doesn't distinguish between graphs and digraphs.
ec_al(EC, AL) :- nonvar(EC), !, ec_gt(EC, GT), gt_al(GT, AL).
ec_al(EC, AL) :- gt_al(GT, AL), ec_gt(EC, GT).

% Convert between graph-term and human-friendly forms in either flow order.
% Fails if arc and edges are intermixed in the human-friendly form.
gt_hf(GT, HF) :- nonvar(GT), !, gt_to_hf(GT, HF).
gt_hf(GT, HF) :- hf_to_gt(HF, GT, _).

% Convert graph-term to human-friendly.
gt_to_hf(GT, HF) :- graph_term(GT, Ns, Es, _), gt_to_hf(Ns, Es, HF).

gt_to_hf(Ns, [], Ns).
gt_to_hf(Ns, [E|Es], [HF|HFs]) :-
  edge_terms(E, _, HF, ENs), subtract(Ns, ENs, Ns1), gt_to_hf(Ns1, Es, HFs).

% Convert human-friendly to graph-term.
hf_to_gt([], G, D) :- (var(D) -> D=u; true), graph_term(G, [], [], D).
hf_to_gt([E|HFs], G_, D) :-
  edge_terms(A, _, E, S), !,    % Doubles as non-isolated node check
  (E = (_>_) -> D=d; D=u),
  hf_to_gt(HFs, G, D),
  graph_term(G, Ns, Es, _),
  ord_add_all(Ns, S, Ns_),
  graph_term(G_, Ns_, [A|Es], D).
hf_to_gt([N|HFs], G_, D) :-
  hf_to_gt(HFs, G, D),
  graph_term(G, Ns, Es, _),
  ord_union(Ns, [N], Ns_),
  graph_term(G_, Ns_, Es, D).

% Convert between edge-clause and human-friendly forms in either flow order.
% Note that isolated nodes are lost in the (?, +) flow order as edge-clause form
% has no way to represent them.
ec_hf(EC, HF) :- nonvar(EC), !, ec_gt(EC, GT), gt_hf(GT, HF).
ec_hf(EC, HF) :- gt_hf(GT, HF), ec_gt(EC, GT).

% Convert between adjacency-list and human-friendly forms in either flow order.
% Note that adjacency-list form doesnt distinguish between graphs and digraphs,
% so the human-friendly form in (+, ?) flow order always uses arcs.
al_hf(AL, HF) :- nonvar(AL), !, gt_al(GT, AL), gt_hf(GT, HF).
al_hf(AL, HF) :- gt_hf(GT, HF), gt_al(GT, AL).


% 6.02 (**) Path from one node to another one.
% Write a predicate path(G, A, B, P) to find an acyclic path P from node A to
% node B in the graph G. The predicate should return all paths via backtracking.

% Flow pattern: (+, +, +, ?). G is in adjacency-list form.

path(G, A, B, P) :- empty_assoc(S), path(G, A, B, P, S).

path(_, A, A, [A], _) :- !.
path(G, A, B, [A|P], Seen) :-
  \+ get_assoc(A, Seen, _), !,
  put_assoc(A, Seen, true, Seen_),
  neighbour_al(A, N, G),
  path(G, N, B, P, Seen_).

neighbour_al(A, B, [n(A, N)|_]) :- maplist(strip_label, N, N1), member(B, N1).
neighbour_al(A, B, [_|AL]) :- neighbour_al(A, B, AL).

strip_label(X/_, X) :- !.
strip_label(X, X).


% 6.03 (*) Cycle from a given node.
% Write a predicate cycle(G, A, P) to find a closed path (cycle) P starting at a
% given node A in the graph G. The predicate should return all cycles via
% backtracking.

% Note that only cycles passing through each intermediate node once are
% returned to avoid infinite sequences of internally-cycling cycles.
% Flow pattern: (+, +, ?). G is in adjacency-list form.

cycle(G, A, [A|P]) :- neighbour_al(A, N, G), path(G, N, A, P).


% 6.04 (**) Construct all spanning trees
% Write a predicate s_tree(Graph,Tree) to construct (by backtracking) all
% spanning trees of a given graph. When you have a correct solution for the
% s_tree/2 predicate, use it to define two other useful predicates:
% is_tree(Graph) and is_connected(Graph). Both are five-minutes tasks!

s_tree(Graph, Tree) :-
  graph_term(Graph, Ns, Es, D),
  Ns = [N|_],
  s_tree([N], Es, Ns, Es1),    % Ns fails to unify if G is disconnected
  graph_term(Tree, Ns, Es1, D).

s_tree(Seen, Es, Seen2, Es3) :-
  select(E, Es, Es1),
  valid_addition(E, Seen),
  edge_terms(E, _, _, Ns),
  ord_add_all(Seen, Ns, Seen1),
  s_tree(Seen1, Es1, Seen2, Es2),
  ord_union(Es2, [E], Es3).
s_tree(Seen, Es, Seen, []) :-
  maplist({Seen}/[E]>>(\+ valid_addition(E, Seen)), Es).

valid_addition(A, Seen) :-
  functor(A, a, _), !,
  edge_terms(A, _, _, [P, Q]),
  ord_memberchk(P, Seen), \+ ord_memberchk(Q, Seen).
valid_addition(E, Seen) :-
  edge_terms(E, _, _, [P, Q]),
  ( ord_memberchk(P, Seen), \+ ord_memberchk(Q, Seen)
  ; ord_memberchk(Q, Seen), \+ ord_memberchk(P, Seen)).

is_tree(Graph) :- s_tree(Graph, Graph).

is_connected(Graph) :- s_tree(Graph, _).


% 6.05 (**) Construct the minimal spanning tree.
% Write a predicate ms_tree(Graph, Tree, Sum) to construct the minimal spanning
% tree of a given labelled graph. Hint: Use the algorithm of Prim. A small
% modification of the solution of 6.04 does the trick.

% On backtracking, this solution produces all other spanning trees in
% decreasingly minimal order. Flow order: (+, ?, ?).

ms_tree(Graph, Tree, Sum) :-
  graph_term(Graph, Ns, Es, D),
  Ns = [N|_],
  predsort(label_compare, Es, SEs),
  s_tree([N], SEs, Ns, Es1),
  graph_term(Tree, Ns, Es1, D),
  foldl([N, Acc, R]>>(label(N, L), R is Acc + L), Es1, 0, Sum).

label(e(_, _, L), L).
label(a(_, _, L), L).

label_compare(O, A, B) :- label(A, L1), label(B, L2), compare(O, L1-A, L2-B).


% 6.06 (**) Graph isomorphism.
% Two graphs G1(N1, E1) and G2(N2, E2) are isomorphic if there is a bijection
% f: N1 -> N2 such that for any nodes X, Y of N1, X and Y are adjacent if and
% only if f(X) and f(Y) are adjacent.

% Write a predicate that determines whether two graphs are isomorphic. Hint: Use
% an open-ended list to represent the function f.

isomorphic(A, B) :- isomorphic(A, B, _).
isomorphic(A, B, I) :-
  graph_term(A, ANs, AEs, _),
  graph_term(B, BNs, BEs, _),
  isomorphic_(ANs, AEs, BNs, BEs, I).

isomorphic_([], [], [], [], _).
isomorphic_([AN|ANs], [], BNs, [], I) :-
  select(BN, BNs, BNs1),
  equate(AN, BN, I),
  isomorphic_(ANs, [], BNs1, [], I).
isomorphic_(ANs, [AE|AEs], BNs, BEs, I) :-
  select(BE, BEs, BEs1),
  equate_edge(AE, BE, I),
  isomorphic_(ANs, AEs, BNs, BEs1, I).

equate_edge(A, B, I) :-
  functor(A, F, _),
  edge_terms(A, _, _, As),
  edge_terms(B, _, _, Bs),
  equate_edge(F, As, Bs, I).

equate_edge(a, [A1, A2], [B1, B2], I) :- equate(A1, B1, I), equate(A2, B2, I).
equate_edge(e, [A1, A2], [B1, B2], I) :- equate(A1, B1, I), equate(A2, B2, I).
equate_edge(e, [A1, A2], [B1, B2], I) :- equate(A1, B2, I), equate(A2, B1, I).

equate(A, B, I) :- memberchk(A=X, I), nonvar(X), !, X = B.
equate(A, B, I) :- memberchk(X=B, I), X = A.


% 6.07 (**) Node degree and graph coloration.
% a) Write a predicate degree(Graph, Node, Deg) that determines the degree of a
%    given node.
% b) Write a predicate that generates a list of all nodes of a graph sorted
%    according to decreasing degree.
% c) Use Welsh-Powell's algorithm to paint the nodes of a graph in such a way
%    that adjacent nodes have different colors.

% Graph must be in adjacency-list form.
degree(Graph, Node, Deg) :- memberchk(n(Node, Ns), Graph), length(Ns, Deg).

degree_sort(Graph, Sorted) :- predsort(degree_compare, Graph, Sorted).

degree_compare(O, n(A, N1), n(B, N2)) :-
  length(N1, L1), length(N2, L2), C1 is -L1, C2 is -L2, compare(O, C1-A, C2-B).

% Graph is in adjacency-list form and Coloring is an open-ended list of node
% name - color variable pairs. The color variables are correctly correlated for
% unification but left underspecified as theres no upper bound on the number of
% colors needed. Flow order: (+, ?).
welsh_powell(Graph, Coloring) :-
  degree_sort(Graph, Sorted), welsh_powell_(Sorted, Coloring), !.

welsh_powell_([], _).
welsh_powell_(Graph, Coloring) :-
  apply_color(Graph, Graph2, Coloring, _), welsh_powell_(Graph2, Coloring).

apply_color(G1, G2, Coloring, C) :- apply_color(G1, G2, Coloring, C, []).

apply_color([], [], _, _, _).
apply_color([n(N, Es)|As], [n(N, Es)|As1], Coloring, C, Cs) :-
  member(E, Es), memberchk(E, Cs), !,
  apply_color(As, As1, Coloring, C, Cs).
apply_color([n(N, _)|As], As1, Coloring, C, Cs) :-
  memberchk(N-C, Coloring),
  apply_color(As, As1, Coloring, C, [N|Cs]).


% 6.08 (**) Depth-first order graph traversal.
% Write a predicate that generates a depth-first order graph traversal sequence.
% The starting point should be specified, and the output should be a list of
% nodes that are reachable from this starting point (in depth-first order).

% Graph is in adjacency-list format. Flow order: (+, +, ?).

dfs(Graph, Start, Order) :- visit_node(Graph, Start, Order, Order, []).

visit_node(Graph, Start, Seen, SeenHoleI, SeenHoleO) :-
  memberchk(n(Start, Ns), Graph),
  SeenHoleI = [Start|SeenHole1],
  visit_neighbours(Graph, Ns, Seen, SeenHole1, SeenHoleO).

visit_neighbours(Graph, Ns, Seen, SeenHoleI, SeenHoleO) :-
  exclude({Seen}/[N]>>memberchk_dl(N, Seen), Ns, UnseenNs),
  visit_neighbours_(Graph, UnseenNs, Seen, SeenHoleI, SeenHoleO).

visit_neighbours_(_, [], _, S, S) :- !.
visit_neighbours_(Graph, Ns, Seen, SeenHoleI, SeenHoleO) :-
  select(N, Ns, Ns1),
  visit_node(Graph, N, Seen, SeenHoleI, SeenHole1),
  visit_neighbours(Graph, Ns1, Seen, SeenHole1, SeenHoleO).

memberchk_dl(M, [H|_]) :- nonvar(H), M=H, !.
memberchk_dl(M, [_|L]) :- nonvar(L), memberchk_dl(M, L).


% 6.09 (**) Connected components.
% Write a predicate that splits a graph into its connected components.

connected_components([], []).
connected_components(Graph, [G1|Components]) :-
  Graph = [n(Start, _)|_],
  dfs(Graph, Start, Reachable), !,
  split_graph(Graph, Reachable, G1, G2),
  connected_components(G2, Components).

split_graph([], _, [], []).
split_graph([A|AL], Keep, [A|G1], G2) :-
  A = n(N, _), memberchk(N, Keep), !, split_graph(AL, Keep, G1, G2).
split_graph([A|AL], Keep, G1, [A|G2]) :- split_graph(AL, Keep, G1, G2).


% 6.10 (**) Bipartite graphs.
% Write a predicate that finds out whether a given graph is bipartite.

is_bipartite(Graph) :-
  connected_components(Graph, Gs),
  maplist([G]>>(chromatic_number(G, N), N =< 2), Gs).

chromatic_number(G, N) :- welsh_powell(G, C), close_dl(C), count_colors(C, N).

count_colors(Coloring, N) :- count_colors(Coloring, 0, N).

count_colors([], Count, Count).
count_colors([_-Color|Cs], Count, N) :-
  nonvar(Color), !, count_colors(Cs, Count, N).
count_colors([_-Color|Cs], Count, N) :-
  Count1 is Count+1, Color = Count1, count_colors(Cs, Count1, N).

close_dl(X) :- var(X), !, X=[].
close_dl([_|X]) :- close_dl(X).


% 6.11 (***) Generate K-regular simple graphs with N nodes.
% In a K-regular graph all nodes have a degree of K; i.e. the number of edges
% incident in each node is K. How many (non-isomorphic!) 3-regular graphs with
% 6 nodes are there?

:- dynamic k_regular_solution/3.

k_regular(K, N, Graph) :- k_regular_solution(K, N, Graph).
k_regular(K, N, Graph) :-
  init_saturation(N, S),
  generate(K, Graph, S, _),
  check_not_found(K, N, Graph),
  assertz(k_regular_solution(K, N, Graph)).

init_saturation(N, NDs) :- numlist(1, N, G), maplist([X, R]>>(R=X-0), G, NDs).

available_edge(N1-N2, [N1-D1|NDs], [N1-D1_, N2-D2_|NDs1]) :-
  select(N2-D2, NDs, NDs1), D1_ is D1+1, D2_ is D2+1.

generate(_, [], [], _).
generate(K, [N1-N2|Es], S, Acc) :-
  available_edge(N1-N2, S, S1),
  \+ memberchk_dl(N1-N2, Acc),
  \+ memberchk_dl(N2-N1, Acc),
  memberchk(N1-N2, Acc),
  include({K}/[_-D]>>(D < K), S1, S2),
  generate(K, Es, S2, Acc).

check_not_found(K, N, G) :- \+ (
  k_regular_solution(K, N, CompareG),
  gt_hf(CompareG_GT, CompareG),
  gt_hf(G_GT, G),
  isomorphic(G_GT, CompareG_GT)).