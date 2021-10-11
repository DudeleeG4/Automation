# How to import
# from _general_multithread import para

import time
import threading

class create_thread(threading.Thread):
    def __init__(self, expensive_function, data):
        threading.Thread.__init__(self)
        self.data = data
        self.expensive_function = expensive_function
        self.finished = False
        self.joined = False
        self.result = None
    def run(self):
        self.result = self.expensive_function(self.data)
        self.finished = True

def para(expensive_function, data_list, max_concurrent_threads=3):
    """
        :param expensive_function: the function on which you want to run in
        parallel
        :param data_list: a list of the data that you want to be passed to the
        function
        :return: a list of the results from the function
    """
    threads = []
    for data in data_list:
        t = create_thread(expensive_function, data)
        threads.append(t)

    limit_enabled = True
    if max_concurrent_threads == 0:
        limit_enabled = False

    concurrent_threads = 0
    for thread in threads:
        if not limit_enabled:
            thread.start()
        else:
            if concurrent_threads < max_concurrent_threads:
                thread.start()
            else:
                # we need to find a thread that is finished, and close it!
                # this is much better than just waiting for the next thread in the
                # list to close itself
                while concurrent_threads == max_concurrent_threads:
                    for thread_to_close in threads:
                        if thread_to_close.finished and not thread_to_close.joined:
                            thread_to_close.joined = True
                            thread_to_close.join()
                            concurrent_threads = concurrent_threads - 1
                            thread.start()
                            break

                    time.sleep(0.1)
                    # lets not use all the CPU checking to see if

            concurrent_threads = concurrent_threads + 1
            # whichever code path we follow, we will ALWAYS have started a thread

            time.sleep(0.1) # wait so were not starting 50000 threads a second :P

        # threads could still in progress
        # wait for all to finish, then continue

    results = []
    error_hosts = []
    for thread in threads:
        thread.join()
        results.append(thread.result)
    # threads are now all done!
    return results