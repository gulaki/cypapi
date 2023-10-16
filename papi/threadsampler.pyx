# cython: language_level=3
import threading
cimport posix.unistd as unistd
from libc.stdlib cimport malloc, free
from libc.stdio cimport printf
import warnings

cdef extern from 'papi.h' nogil:
    cdef int PAPI_OK
    cdef int PAPI_EISRUN
    int PAPI_thread_init(unsigned long (*id_fn) ())
    int PAPI_register_thread()
    int PAPI_unregister_thread()
    int PAPI_read_ts(int EventSet, long long * values, long long *cyc)
    int PAPI_start(int EventSet)
    int PAPI_stop(int EventSet, long long * values)

cdef unsigned long get_thread_id() nogil:
    with gil:
        return threading.get_native_id()

def pyPAPI_thread_init():
    cdef int papi_errno = PAPI_thread_init(get_thread_id)
    if papi_errno != PAPI_OK:
        raise Exception('PAPI Error: PAPI_thread_init failed')

cdef class ThreadSamplerEventSet:
    cdef int evtset_id
    cdef int num_events
    cdef int interval_ms
    cdef object thread
    cdef int stop_event
    cdef long long *values

    def __cinit__(self, eventset: object, interval_ms: int):
        self.evtset_id = eventset.get_id()
        self.num_events = eventset.num_events()

        self.interval_ms = interval_ms
        self.thread = threading.Thread(target=self.run)
        self.stop_event = 0
        self.values = <long long *> malloc(self.num_events * sizeof(long long))

    def __dealloc__(self):
        free(self.values)

    def start(self):
        self.thread.start()

    def stop(self):
        self.stop_event = 1
        self.thread.join()

    cpdef run(self):
        cdef long long cyc = -1
        cdef int i
        cdef int papi_errno = PAPI_register_thread()
        if papi_errno != PAPI_OK:
            raise Exception('PAPI Error: PAPI_register thread failed.')

        papi_errno = PAPI_start(self.evtset_id)
        if papi_errno == PAPI_EISRUN:
            warnings.warn('Event set is already running. Ignoring PAPI_start.')
        elif papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: PAPI_Start failed.')

        with nogil:
            while True:
                papi_errno = PAPI_read_ts(self.evtset_id, self.values, &cyc)
                printf("%lld\t", cyc)
                for i in range(self.num_events):
                    printf("%lld\t", self.values[i])
                printf("\n")
                unistd.usleep(self.interval_ms * 1000)
                if self.stop_event:
                    break
        
        papi_errno = PAPI_stop(self.evtset_id, self.values)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: PAPI_stop failed.')

        papi_errno = PAPI_unregister_thread()
        if papi_errno != PAPI_OK:
            raise Exception('PAPI Error: PAPI_unregister_thread failed.')
