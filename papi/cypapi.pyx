# cython: language_level=3
from cpython.mem cimport PyMem_Malloc, PyMem_Free
import atexit
import warnings

from papih cimport *

def pyPAPI_library_init():
    cdef int papi_errno = PAPI_library_init(PAPI_VER_CURRENT)
    if (papi_errno != PAPI_VER_CURRENT):
        raise Exception('Failed to initialize PAPI_Library')

def pyPAPI_get_version_string():
    ver = f'{PAPI_VERSION_MAJOR(PAPI_VERSION)}.{PAPI_VERSION_MINOR(PAPI_VERSION)}.{PAPI_VERSION_REVISION(PAPI_VERSION)}.{PAPI_VERSION_INCREMENT(PAPI_VERSION)}'
    return ver

def pyPAPI_is_initialized():
    return PAPI_is_initialized()

@atexit.register
def pyPAPI_shutdown():
    PAPI_shutdown()

def pyPAPI_strerror(int papi_errno):
    cdef char* c_str = PAPI_strerror(papi_errno)
    return str(c_str, encoding='utf-8')

def pyPAPI_num_components():
    return PAPI_num_components()

def pyPAPI_get_component_index(str name):
    return PAPI_get_component_index(name.encode('utf-8'))

def pyPAPI_get_real_cyc():
    return PAPI_get_real_cyc()

def pyPAPI_get_real_nsec():
    return PAPI_get_real_nsec()

def pyPAPI_get_real_usec():
    return PAPI_get_real_usec()

def pyPAPI_get_virt_cyc():
    return PAPI_get_virt_cyc()

def pyPAPI_get_virt_nsec():
    return PAPI_get_virt_nsec()

def pyPAPI_get_virt_usec():
    return PAPI_get_virt_usec()

class PyPAPI_get_component_info:

    def __init__(self, int cidx):
        cdef const PAPI_component_info_t* cmp_info = PAPI_get_component_info(cidx)
        if not cmp_info:
            raise Exception(f'PAPI Error: Component not found.')
        self.name = str(cmp_info.name, encoding='utf-8')
        self.short_name = str(cmp_info.name, encoding='utf-8')
        self.description = str(cmp_info.description, encoding='utf-8')
        self.version = str(cmp_info.version, encoding='utf-8')
        self.support_version = str(cmp_info.support_version, encoding='utf-8')
        self.kernel_version = str(cmp_info.kernel_version, encoding='utf-8')
        self.disabled_reason = str(cmp_info.disabled_reason, encoding='utf-8')
        self.disabled = cmp_info.disabled
        self.initialized = cmp_info.initialized
        self.CmpIdx = cmp_info.CmpIdx
        self.num_cntrs = cmp_info.num_cntrs
        self.num_mpx_cntrs = cmp_info.num_mpx_cntrs
        self.num_preset_events = cmp_info.num_preset_events
        self.num_native_events = cmp_info.num_preset_events
        self.default_domain = cmp_info.default_domain
        self.available_domains = cmp_info.available_domains
        self.default_granularity = cmp_info.default_granularity
        self.available_granularities = cmp_info.available_granularities
        self.hardware_intr_sig = cmp_info.hardware_intr_sig
        self.component_type = cmp_info.component_type

    def __str__(self):
        return str(self.__dict__)

cdef class PyPAPI_enum_component_events:
    cdef int ntv_code
    cdef int cidx
    cdef int modifier

    def __cinit__(self, int cidx):
        self.cidx = cidx
        self.modifier = PAPI_ENUM_FIRST
        self.ntv_code = 0 | PAPI_NATIVE_MASK
        self.next_event()
    
    def next_event(self):
        cdef int papi_errno
        if self.modifier == PAPI_ENUM_FIRST:
            papi_errno = PAPI_enum_cmp_event(&self.ntv_code, PAPI_ENUM_FIRST, self.cidx)
            if papi_errno != PAPI_OK:
                raise Exception('PAPI Error {papi_errno}: Failed to enumerate component event')
            self.modifier = PAPI_ENUM_EVENTS
            return self.ntv_code
        papi_errno = PAPI_enum_cmp_event(&self.ntv_code, PAPI_ENUM_EVENTS, self.cidx)
        if papi_errno != PAPI_OK:
            raise StopIteration
        return self.ntv_code

    def __iter__(self):
        return self

    def __next__(self):
        return self.next_event()

def pyPAPI_event_code_to_name(int event_code):
    cdef char out[1024]
    cdef int papi_errno = PAPI_event_code_to_name(event_code, out)
    if papi_errno == PAPI_ENOMEM:
        warnings.warn('PAPI has a bug getting event name from code')
    elif papi_errno != PAPI_OK:
        raise Exception(f'PAPI Error {papi_errno}: Failed to get event name from code')
    event_name = str(out, encoding='utf-8')
    return event_name

def pyPAPI_event_name_to_code(str eventname):
    cdef bytes c_name = eventname.encode('utf-8')
    cdef int out = -1
    cdef papi_errno = PAPI_event_name_to_code(c_name, &out)
    if papi_errno != PAPI_OK:
        raise Exception(f'PAPI Error {papi_errno}: Failed to get event code')
    return out

cdef class PyPAPI_EventSet:
    cdef int event_set

    def __cinit__(self):
        self.event_set = PAPI_NULL
        cdef papi_errno = PAPI_create_eventset(&self.event_set)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI_Error {papi_errno}: Failed to create PAPI Event set.')

    def __str__(self):
        return f'PAPI Event set {self.event_set}'

    def cleanup(self):
        cdef papi_errno = PAPI_cleanup_eventset(self.event_set)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI_Error {papi_errno}: Failed to cleanup eventset.')

    def __dealloc__(self):
        self.cleanup()
        cdef papi_errno = PAPI_destroy_eventset(&self.event_set)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI_Errno {papi_errno}: Failed to destroy eventset.')

    def num_events(self):
        return PAPI_num_events(self.event_set)

    def assign_component(self, int cidx):
        cdef int papi_errno = PAPI_assign_eventset_component(self.event_set, cidx)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: Failed to assign component to eventset {self.event_set}')

    def reset(self):
        cdef int papi_errno = PAPI_reset(self.event_set)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: Failed to reset eventset {self.event_set}')

    def add_event(self, int event):
        cdef int papi_errno = PAPI_add_event(self.event_set, event)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: Failed to add event.')

    def add_named_event(self, str name):
        cdef bytes c_name = name.encode('utf-8')
        cdef int papi_errno = PAPI_add_named_event(self.event_set, c_name)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: Failed to add event {name} to eventset {self.event_set}')

    def start(self):
        cdef int papi_errno = PAPI_start(self.event_set)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: PAPI_start faled')

    def stop(self):
        cdef int num_events = self.num_events()
        cdef long long *values = <long long *> PyMem_Malloc(num_events * sizeof(long long))
        if not values:
            raise MemoryError('Failed to allocate long long array')
        cdef int papi_errno = PAPI_stop(self.event_set, values)
        if papi_errno != PAPI_OK:
            PyMem_Free(values)
            raise Exception(f'PAPI Error {papi_errno}: PAPI_stop faled')
        result = [values[i] for i in range(num_events)]
        PyMem_Free(values)
        return result

    def read(self):
        cdef int num_events = self.num_events()
        cdef long long *values = <long long *> PyMem_Malloc(num_events * sizeof(long long))
        if not values:
            raise MemoryError('Failed to allocate long long array')
        cdef int papi_errno = PAPI_read(self.event_set, values)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: PAPI_read failed')
        result = [values[i] for i in range(num_events)]
        PyMem_Free(values)
        return result

    def read_ts(self):
        cdef int num_events = self.num_events()
        cdef long long *values = <long long *> PyMem_Malloc(num_events * sizeof(long long))
        if not values:
            raise Exception(f'Failed to allocate array')
        cdef long long cyc = -1
        cdef int papi_errno = PAPI_read_ts(self.event_set, values, &cyc)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: PAPI_read_ts failed')
        result = [values[i] for i in range(num_events)]
        PyMem_Free(values)
        return result, cyc

    def accum(self, list values):
        cdef int num_events = self.num_events()
        if num_events != len(values):
            raise Exception("Length of values and number of added events don't match")
        cdef long long * vals = <long long*> PyMem_Malloc(num_events * sizeof(long long))
        if not vals:
            raise Exception(f'Failed to allocate array')
        cdef int i
        for i in range(num_events):
            vals[i] = values[i]
        cdef int papi_errno = PAPI_accum(self.event_set, vals)
        if papi_errno != PAPI_OK:
            PyMem_Free(vals)
            raise Exception(f'PAPI Error {papi_errno}: PAPI_accum failed')
        for i in range(num_events):
            values[i] = vals[i]
        PyMem_Free(vals)

    def list_events(self):
        cdef int num_events = self.num_events()
        cdef int *evts = <int *> PyMem_Malloc(num_events * sizeof(int))
        if not evts:
            raise Exception('Failed to allocate array')
        cdef int number = 0
        cdef int papi_errno = PAPI_list_events(self.event_set, evts, &number)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: PAPI_list_events failed.')
        result = [evts[i] for i in range(num_events)]
        PyMem_Free(evts)
        return result

    def state(self):
        cdef int val = -1
        cdef papi_errno = PAPI_state(self.event_set, &val)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: PAPI_state failed.')
        return val

    def write(self, list values):
        cdef int num_events = self.num_events()
        if len(values) > num_events:
            raise Exception('Too many values to write')
        cdef long long *vals = <long long *> PyMem_Malloc(len(values))
        if not vals:
            raise Exception('Failed to allocate array')
        cdef int i
        for i in range(len(values)):
            vals[i] = values[i]
        cdef papi_errno = PAPI_write(self.event_set, vals)
        PyMem_Free(vals)
        if papi_errno != PAPI_OK:
            raise Exception(f'PAPI Error {papi_errno}: PAPI_write failed')

    def get_component(self):
        cdef int cid = PAPI_get_eventset_component(self.event_set)
        if cid < 0:
            raise Exception(f'PAPI Error {cid}: Failed to get eventset component index')
        return cid

del atexit, warnings