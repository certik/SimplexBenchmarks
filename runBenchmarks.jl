
models = [("greenbea",20),("stocfor3",80),("ken-13",400),("fome12",450)]

# dump simplex data
cd("GenerateData")
for (n,i) in models
    if !isfile("$(n)")
        run(`gunzip -k $(n).gz`)
    end
    if !isfile("$(n).dump")
        run(`julia gendump.jl $(n) $i`)
    end
end
cd("..")

benchmarks = [("Julia",["julia","Julia/runbench.jl"]),("C++",["C++/runbench"]),
            ("C++bnd",["C++/runbenchBoundsCheck"]),
            ("matlab",["julia","MATLAB/runmatlab.jl"]),
            ("PyPy",["pypy","Python/runbench.py"]),
            ("Python",["python2.7","Python/runbench.py"])]

operations = [("mtvec","Matrix-transpose-vector product with non-basic columns"),
    ("smtvec","Hyper-sparse matrix-transpose-vector product"),
    ("rto2","Two-pass dual ratio test"),
    ("srto2","Hyper-sparse two-pass dual ratio test"),
    ("updul","Update dual iterate with cost shifting"),
    ("supdul","Hyper-sparse update dual iterate with cost shifting") ]

type ExperimentRow
    model
    language
    operation
    t
end

data = Array(ExperimentRow,0)

# repeat this many times, take minimum time for each operation
nrepeat = 3

for (n,i) in models
    for (language,command) in benchmarks
        d = Dict()
        for k in 1:nrepeat
            output = readall(`$command GenerateData/$(n).dump`)
            lines = split(output,"\n")
            println("$(lines[1])\n$(lines[2])")
            offset = 3 # 3rd line has the result of the operations
            for (shortname,o) in operations
                l = split(lines[offset]," ")

                first,last = search(lines[offset],o)
                if (first == last || l[end] != "sec")
                    error("Expected $shortname in line:\n$(lines[offset])")
                end
                t = float(l[end-1])
                if k > 1
                    d[o] = min(d[o],t)
                else
                    d[o] = t
                end
                offset += 1
            end
        end
        for (shortname,o) in operations
            push!(data,ExperimentRow(n,language,shortname,d[o]))
        end
    end
    println()
end

println()
for (shortname,o) in operations
    for (language,command) in benchmarks
        push!(data,ExperimentRow("mean",language,shortname,1.))
    end
end

for (n,i) in models
    print("$n (relative to C++bnd):\n\t")
    for (language,command) in benchmarks
        print("$language\t")
    end
    print("Basetime")
    println()
    for (shortname,o) in operations
        print("$shortname:\t")
        baseline = data[map(row->(row.model == n && row.operation == shortname && row.language == "C++bnd"), data)][1].t
        for (language,command) in benchmarks
            t = data[map(row->(row.model == n && row.operation == shortname && row.language == language), data)][1].t
            t /= baseline
            @printf("%.2f\t",t)
            # add to mean
            data[map(row->(row.model == "mean" && row.operation == shortname && row.language == language), data)][1].t *= t
        end
        @printf("%.5f",baseline)
        println()
    end
    println()
    println()
end

print("Geometric mean (relative to C++bnd):\n\t")
for (language,command) in benchmarks
    print("$language\t")
end
println()
for (shortname,o) in operations
    print("$shortname:\t")
    for (language,command) in benchmarks
        t = data[map(row->(row.model == "mean" && row.operation == shortname && row.language == language), data)][1].t
        t = t^(1./length(models))
        @printf("%.2f\t",t)
    end
    println()
end
println()
println()
println("Key:")
for (shortname,o) in operations
    println("$shortname = $o")
end
println("C++bnd = C++ with bounds checking")





        



