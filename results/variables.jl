locations = ["IT-Lav",
            "SE-Nor",
            "DE-Wet",
            "CZ-BK1",
            #"NL-Loo",
            "SE-Htm",
            "DE-Obe",
            "CZ-Stn",
            "SE-Sk2",
            "DE-Bay",
            "FI-Hyy",
            "BE-Vie",
            "DE-Hzd",
            "DE-RuW",
            "SE-Ros",
            #"FR-Pue",
            "DE-Lkb",
            "FI-Let",
            "IT-La2",
            "IT-Ren",
            #"SE-Svb",
            "DE-Hai",
            "CZ-Lnz"
]

start_preddate = Date(2013,09,09)
start_date = Date(2000,01,01)
stop_date = Date(2020,12,31)
time_full = start_date:Day(1):stop_date
time_train = start_date:Day(1):Date(2013,09,08)
time_pred = start_preddate:Day(1):stop_date

path = joinpath(dirname(@__FILE__), "..")