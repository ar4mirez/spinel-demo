# job-worker

A background job queue on Spinel: a producer (`bin/enqueue`) adds jobs, and long-running worker processes (`bin/worker`) run them on a pool of threads. The queue is a directory of JSON files, one per job, and jobs move between states with `File.rename`. That move is atomic, so any number of worker processes, each with any number of threads, can share one queue with no lock file and no database. It uses `Thread`, `Thread::Queue`, `Mutex`, `Signal.trap`, `Process.kill` and `fork` from core Ruby, and `JSON`, `FileUtils` and `OptionParser` from the standard library. Minitest is the only gem, for `spinel test`.

| File | What it does |
| --- | --- |
| [lib/job_worker/queue.rb](lib/job_worker/queue.rb) | The queue: `enqueue`, `claim`, `complete`, `fail` (retries, then gives up), `recover` (requeues jobs whose worker died), `counts`, `jobs` |
| [lib/job_worker/worker.rb](lib/job_worker/worker.rb) | The worker: N threads claiming and running jobs, logging through a `Thread::Queue`, stopping cleanly when asked |
| [lib/job_worker/jobs.rb](lib/job_worker/jobs.rb) | The job types: `square N`, `fib N`, `wordcount TEXT...`, `sleep MS`, `flaky` (fails once, then succeeds) and `boom` (always fails) |
| [bin/enqueue](bin/enqueue) | `enqueue TYPE [ARG...]` adds one job; `enqueue --demo` adds one of each type |
| [bin/worker](bin/worker) | `worker [--threads N] [--drain]` runs jobs until SIGINT or SIGTERM, or with `--drain` until the queue is empty |
| [bin/status](bin/status) | `status [--json]` shows how many jobs are in each state, and the finished and failed jobs |
| [test/](test/) | Minitest tests for the queue (including threads and forked processes racing for jobs), the job types and the worker |

## How the queue works

The queue lives in `tmp/queue/` inside this example (git ignores `tmp/`):

```
tmp/queue/
  pending/ID.json        waiting to run; IDs sort in the order jobs were added
  running/ID.PID.json    claimed by the worker process PID
  done/ID.json           finished, with its result, the worker thread and the time
  failed/ID.json         gave up, with the last error
  incoming/              files being written; each is renamed into place when complete
```

- **Claiming.** A worker thread renames the oldest file in `pending/` to `running/ID.PID.json`. When two workers race for a job, one rename succeeds and the other gets `Errno::ENOENT` and tries the next job, so a job is never run twice at the same time.
- **Retries.** A job that raises goes back to `pending/` until it has used `max_attempts` (3) attempts, then moves to `failed/`. An unknown job type or a bad argument is a permanent error and goes to `failed/` at once.
- **Stopping.** On SIGINT or SIGTERM a worker finishes the jobs it is running, claims no more, and exits 0. The signal handler only sets a flag.
- **Crashes.** A worker killed mid-job (`kill -9`, a crash, a lost machine) leaves its job in `running/`. The next worker to start checks the PID in each running file with `Process.kill(0, pid)` and puts the jobs of processes that no longer exist back in `pending/`.

A job can therefore run more than once (a worker that crashes after finishing a job but before recording it), so jobs should be safe to repeat. This is the usual contract for background job queues.

## Prerequisites

Spinel 0.1.0 on your `PATH` (see the [top-level README](../../README.md#install-spinel)).

## Run it

```sh
cd examples/job-worker
spinel install --frozen          # Minitest, for spinel test
spinel test                      # 18 tests, 0 failures, 0 errors

spinel run bin/enqueue --demo    # one job of each type
spinel run bin/worker --drain    # run them all, then exit
spinel run bin/status
```

To see the long-running case, start one or more workers in their own terminals and add jobs from another:

```sh
spinel run bin/worker --threads 4        # terminal 1: runs until Ctrl-C
spinel run bin/worker                    # terminal 2: a second worker on the same queue
spinel run bin/enqueue sleep 2000        # terminal 3: watch a worker pick it up
spinel run bin/enqueue fib 90
spinel run bin/enqueue wordcount "the cat and the hat"
spinel run bin/status
```

Press Ctrl-C in a worker's terminal while it runs a `sleep 2000` job: it finishes the job, prints `stopped`, and exits. Delete `tmp/queue/` to start over with an empty queue. The scripts in `bin/` start with `#!/usr/bin/env spinel`, so `bin/worker` works too.

## Smoke check

```sh
./smoke            # or, from the repository root: bin/smoke job-worker
```

It installs Minitest and runs `spinel test`, then, on an empty `tmp/queue/`:

1. adds the demo jobs and runs a draining worker, checking results, the retry of `flaky` and the three failed attempts of `boom`;
2. starts two worker processes in the background, adds 20 jobs while they run, and checks that every job ran exactly once and that both processes ran some;
3. sends them SIGTERM during a slow job and checks that the job finished and both exited 0;
4. kills a worker with SIGKILL mid-job and checks that the next worker recovers and runs the job;
5. checks the errors for an unknown job type and a bad `--threads`.

Every worker it starts is stopped before it exits.

## Known issues (spinel 0.1.0)

None: `Thread`, `Thread::Queue`, `Mutex`, `Signal.trap` for `INT` and `TERM`, `Process.kill` (including signal 0 to test for a process), `Process.spawn`, `Process.wait`, `fork`, `IO.pipe`, atomic `File.rename` between directories, `JSON` and `OptionParser` all ran on Spinel 0.1.0 with no workaround.
