/* -*- C -*- */
/*
 * threads.c: multi thread extensions.
 *
 *   Copyright (c) 2010  Takashi Kato <ktakashi@ymail.com>
 *
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *  $Id: $
 */
#define LIBSAGITTARIUS_BODY
#include "threads.h"

static SgObject thread_error_handler(SgObject *args, int argc, void *data)
{
  return SG_UNDEF;
}

static SG_DEFINE_SUBR(thread_error_handler_STUB, 1, 0, thread_error_handler, SG_FALSE, NULL);

SgObject Sg_MakeThread(SgProcedure *thunk, SgObject name)
{
  SgVM *current = Sg_VM(), *vm;
  if (SG_PROCEDURE_REQUIRED(thunk) != 0) {
    Sg_Error(UC("thunk required, but got %S"), thunk);
  }
  vm = Sg_NewVM(current, name);
  vm->thunk = thunk;
  vm->exceptionHandler = SG_OBJ(&thread_error_handler_STUB);
  return SG_OBJ(vm);
}

static void thread_cleanup(void *data)
{
  SgVM *vm = SG_VM(data);
  SgObject exc;

  /* change this VM state to TERMINATED, and signals the change
     to the waiting threads. */
  Sg_LockMutex(&vm->vmlock);
  vm->threadState = SG_VM_TERMINATED;
  if (vm->canceller) {
    /* this thread is cancelled */
    /* TODO set result exception */
  }
  Sg_NotifyAll(&vm->cond);
  Sg_UnlockMutex(&vm->vmlock);
}

static void* thread_entry(void *data)
{
  SgVM *vm = SG_VM(data);
  thread_cleanup_push(thread_cleanup, vm);
  if (Sg_SetCurrentVM(vm)) {
    SG_UNWIND_PROTECT {
      vm->result = Sg_Apply(SG_OBJ(vm->thunk), SG_NIL);
    } SG_WHEN_ERROR {
      SgObject exc;
      switch (vm->escapeReason) {
      case SG_VM_ESCAPE_CONT:
	vm->resultException = Sg_MakeString(UC("stale continuation throws"), SG_LITERAL_STRING);
	break;
      default:
	Sg_Panic("unknown escape");
      case SG_VM_ESCAPE_ERROR:
	/* TODO thread exception */
	break;
      }
    } SG_END_PROTECT;
  } else {
    /* TODO exception */
  }
  thread_cleanup_pop(TRUE);
  return NULL;
}

SgObject Sg_ThreadStart(SgVM *vm)
{
  int err_state = FALSE;
  Sg_LockMutex(&vm->vmlock);
  if (vm->threadState != SG_VM_NEW) {
    err_state = TRUE;
  } else {
    ASSERT(vm->thunk);
    vm->threadState = SG_VM_RUNNABLE;
    Sg_InternalThreadStart(&vm->thread, thread_entry, vm);
  }
  Sg_UnlockMutex(&vm->vmlock);
  if (err_state) Sg_Error(UC("attempt to start an already-started thread: %S"), vm);
  return SG_OBJ(vm);
}

SgObject Sg_ThreadJoin(SgVM *vm, SgObject timeout, SgObject timeoutval)
{
  int msec = -1;
  int success = TRUE;
  SgObject result = SG_FALSE, resultx = SG_FALSE;
  if (SG_REALP(timeout)) {
    msec = Sg_GetIntegerClamp(timeout, SG_CLAMP_NONE, NULL);
  }
  Sg_LockMutex(&vm->vmlock);
  while (vm->threadState != SG_VM_TERMINATED) {
    if (SG_REALP(timeout)) {
      success = Sg_WaitWithTimeout(&vm->cond, &vm->vmlock, msec);
      break;
    } else {
      success = Sg_Wait(&vm->cond, &vm->vmlock);
    }
  }
  if (success) {
    result = vm->result;
    resultx = vm->resultException;
    vm->resultException = SG_FALSE;
  }
  Sg_UnlockMutex(&vm->vmlock);
  if (!success) {
    if (SG_UNBOUNDP(timeoutval)) {
      /* TODO make join-timeout-exception */
      SgObject e = SG_UNDEF;
      result = Sg_Raise(e, FALSE);
    } else {
      result = timeoutval;
    }
  } else if (Sg_ConditionP(resultx)) {
    result = Sg_Raise(resultx, FALSE);
  }
  return result;
}

SgObject Sg_ThreadStop(SgVM *target, SgObject timeout, SgObject timeoutval)
{
  int invalid_state = FALSE;
  SgVM *taker = NULL;
  SgVM *vm = Sg_VM();
  int msec;
  int success;
  if (SG_REALP(timeout)) {
    msec = Sg_GetIntegerClamp(timeout, SG_CLAMP_NONE, NULL);
  }

 retry:
  Sg_LockMutex(&target->vmlock);
  if (target->threadState != SG_VM_RUNNABLE &&
      target->threadState != SG_VM_STOPPED) {
    invalid_state = TRUE;
  } else if (target->inspector != NULL &&
	     target->inspector != vm &&
	     target->inspector->state != SG_VM_TERMINATED) {
    taker = target->inspector;
  } else {
    if (target->inspector != vm) {
      target->inspector = vm;
      target->stopRequest = TRUE;
      target->attentionRequest = TRUE;
    }
    while (target->threadState != SG_VM_STOPPED) {
      if (SG_REALP(timeout)) {
	success = Sg_WaitWithTimeout(&target->cond, &target->vmlock, msec);
      } else {
	success = Sg_Wait(&target->cond, &target->vmlock);
      }
    }
  }
  Sg_UnlockMutex(&target->vmlock);
  if (invalid_state) {
    Sg_Error(UC("cannot stop a thread %S since it is in neither runnable or stopped state"),
	     target);
  }
  if (taker != NULL) {
    Sg_Error(UC("target %S is already under inspection by %S"), target, taker);
  }
  if (!success) return timeoutval;
  return SG_OBJ(target);
}

SgObject Sg_ThreadCont(SgVM *target)
{
  int not_stopped = FALSE;
  SgVM *stopped_by_other = NULL;
  Sg_LockMutex(&target->vmlock);
  if (target->inspector == NULL) {
    not_stopped = TRUE;
  } else if (target->inspector != Sg_VM() &&
	     target->inspector->state != SG_VM_TERMINATED) {
    stopped_by_other = target->inspector;
  } else {
    target->inspector = NULL;
    target->threadState = SG_VM_RUNNABLE;
    target->stopRequest = FALSE;
    Sg_NotifyAll(&target->cond);
  }
  Sg_UnlockMutex(&target->vmlock);
  if (not_stopped) Sg_Error(UC("target %S is not stopped"), target);
  if (stopped_by_other) Sg_Error(UC("target %S is stopped by other thread %S"),
				 target, stopped_by_other);
  return SG_OBJ(target);
}

SgObject Sg_ThreadSleep(SgObject timeout)
{
  SgInternalCond dummyc;
  SgInternalMutex dummym;
  int intr = FALSE;
  int msec = Sg_GetIntegerClamp(timeout, SG_CLAMP_NONE, NULL);
  Sg_InitMutex(&dummym, FALSE);
  Sg_InitCond(&dummyc);
  Sg_LockMutex(&dummym);
  intr = Sg_WaitWithTimeout(&dummyc, &dummym, msec);
  Sg_UnlockMutex(&dummym);
  Sg_DestroyMutex(&dummym);
  Sg_DestroyCond(&dummyc);
  return SG_UNDEF;
}

SgObject Sg_ThreadTerminate(SgVM *target)
{
  SgVM *vm = Sg_VM();
  if (target == vm) {
    /* self termination */
    Sg_LockMutex(&target->vmlock);
    if (target->canceller == NULL) {
      target->canceller = vm;
    }
    Sg_UnlockMutex(&target->vmlock);
    Sg_ExitThread(&target->thread, NULL);
  } else {
    Sg_LockMutex(&target->vmlock);
    if (target->canceller == NULL) {
      target->canceller = vm;
      Sg_TerminateThread(&target->thread);
    }
    Sg_UnlockMutex(&target->vmlock);
  }
  return SG_UNDEF;
}

extern void Sg__Init_sagittarius_threads();
extern void Sg__InitMutex();

void Sg_Init_sagittarius__threads()
{
  Sg__InitMutex();
  Sg__Init_sagittarius_threads();
  SG_PROCEDURE_NAME(&thread_error_handler_STUB)
    = Sg_MakeString(UC("thread-exception-handler"), SG_LITERAL_STRING);
}
/*
  end of file
  Local Variables:
  coding: utf-8-unix
  End:
*/
