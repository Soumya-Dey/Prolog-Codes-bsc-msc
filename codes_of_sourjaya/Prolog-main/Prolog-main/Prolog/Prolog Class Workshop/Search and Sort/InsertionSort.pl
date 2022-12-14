/*Write a program in prolog for Insertion Sort
	TRICK:
	1)Have two seperate predicates:
	2)One that inserts an element in a list.
	3)One that executes the sort 

	INSERT:
	Inserts a value in the correct position in a list.
	Does this by comparing the value with the head of a list.
	If there is no list, just copy the value.
	If there is a list, compare X, and the Head H.
	If X is equal or smaller, insert it behind H.
	Else, check the next item of the list 
	
	Insort:
	Does the actual sorting.
	Breaks down the list until the last element.
	At that point, it starts "inserting" the numbers in the new list.
	Considering each number is "inserted", at each point the new list is sorted.
	Hence, once all the elements have been inserted, the full list has been sorted.*/

insert(X,[],[X]).
insert(X,[H|T],[X,H|T]):- X =< H,!.
insert(X,[H|T1],[H|T2]):- insert(X,T1,T2).

insort([],[]).
insort([H|T],Sorted):- insort(T,Sorted2), insert(H,Sorted2,Sorted).