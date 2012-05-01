

#include <stdio.h>

#include <cuda.h>
#include <cuda_runtime.h>
#include <driver_functions.h>

#include "pnfa.h"


/* Allocate and initialize State */
__device__ inline State* pstate(int c, State *out, State *out1)
{
	State *s = (states + pnstate); // assign a state
	
	s->id = pnstate++;
	s->lastlist = 0;
	s->c = c;
	s->out = out;
	s->out1 = out1;
	
	// device pointer of itself
	// serves no real purpose other than to help transfer the NFA over
	s->dev = NULL;
	
	s->free = 0;
	return s;
}


/* Initialize frag struct. */
__device__ inline Frag
pfrag(State *start, Ptrlist *out)
{
	Frag n = { start, out };
	return n;
}

/* Create singleton list containing just outp. */
__device__ inline Ptrlist*
plist1(State **outp)
{
	Ptrlist *l;

	l = (Ptrlist*)outp;
	l->next = NULL;
	return l;
}

/* Patch the list of states at out to point to start. */
__device__ inline void
ppatch(Ptrlist *l, State *s)
{
	Ptrlist *next;

	for(; l; l=next){
		next = l->next;
		l->s = s;
	}
}

/* Join the two lists l1 and l2, returning the combination. */
__device__ inline Ptrlist*
pappend(Ptrlist *l1, Ptrlist *l2)
{
	Ptrlist *oldl1;

	oldl1 = l1;
	while(l1->next)
		l1 = l1->next;
	l1->next = l2;
	return oldl1;
}


/*
 * Convert postfix regular expression to NFA.
 * Return start state.
 */
 
__device__ inline State*
ppost2nfa(char *postfix)
{
	char *p;
	Frag stack[1000], *stackp, e1, e2, e;
	State *s;

	// fprintf(stderr, "postfix: %s\n", postfix);

	if(postfix == NULL)
		return NULL;

#define push(s) *stackp++ = s
#define pop() *--stackp

	stackp = stack;
	for(p=postfix; *p; p++){
		switch(*p){
            case ANY: /* any (.) */
				s = pstate(Any, NULL, NULL);
				push(pfrag(s, plist1(&s->out)));
				break;
			default:
				s = pstate(*p, NULL, NULL);
				push(pfrag(s, plist1(&s->out)));
				break;
			case CONCATENATE:	/* catenate */
				e2 = pop();
				e1 = pop();
				ppatch(e1.out, e2.start);
				push(pfrag(e1.start, e2.out));
				break;
			case ALTERNATE:	/* alternate (|)*/
				e2 = pop();
				e1 = pop();
				s = pstate(Split, e1.start, e2.start);
				push(pfrag(s, pappend(e1.out, e2.out)));
				break;
			case QUESTION:	/* zero or one (?)*/
				e = pop();
				s = pstate(Split, e.start, NULL);
				push(pfrag(s, pappend(e.out, plist1(&s->out1))));
				break;
			case STAR:	/* zero or more (*)*/
				e = pop();
				s = pstate(Split, e.start, NULL);
				ppatch(e.out, s);
				push(pfrag(s, plist1(&s->out1)));
				break;
			case PLUS:	/* one or more (+)*/
				e = pop();
				s = pstate(Split, e.start, NULL);
				ppatch(e.out, s);
				push(pfrag(e.start, plist1(&s->out1)));
				break;
		}
	}

	e = pop();
	if(stackp != stack)
		return NULL;

	ppatch(e.out, &pmatchstate);

	return e.start;
#undef pop
#undef push
}

__global__ void parallelNFAKernel(char *postfix) {

	State s[100];
	
	pnstate = 0;
	states = s;

	printf("Begun \n");
	printf("Postfix %s\n", postfix);
	
	State *start = ppost2nfa(postfix);

	printf("done\n");
	printf("start %c\n", start->c);
	printf("start %c\n", start->out->c);
	printf("start %c\n", start->out->out->c);
	printf("start %c\n", start->out->out->out->c);
	printf("start %c\n", start->out->out->out->out->c);
	
}

void parallelNFA(char *postfix) {
	
	parallelNFAKernel<<<1,1>>>(postfix);	

}
