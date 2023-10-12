struct Location{N,I,FT,CZ}
    name::N
    latitude::I
    longitude::I
    forest_type::FT
    climate_zone::CZ
end

acro2name_forest = Dict(
    "ENF" => "Evergreen needle-leaf forest",
    "DBF" => "Deciduous broadleaf forest",
    "MF" => "Mixed forest",
    "EBF" => "Evergreen broadleaf forest"
)


IT_Lav = Location(
    "IT-Lav",
    45.9562,
    11.2813,
    "enf",
    "Cfa/Dfb/Cfb"
)

SE_Nor = Location(
    "SE-Nor",
    60.08649722,
    17.47950278,
    "enf",
    "Dfb"
)

DE_Wet = Location(
    "DE-Wet",
    50.4535,
    11.45753333,
    "enf",
    "Dfb"
)

CZ_BK1 = Location(
    "CZ-BK1",
    49.50207615,
    18.53688247,
    "enf",
    "Dfb"
)

NL_Loo = Location(
    "NL-Loo",
    52.166581,
    5.743556,
    "enf",
    "Cfb"
)

SE_Htm = Location(
    "SE-Htm",
    56.09763,
    13.41897,
    "enf",
    "Dfb"
)

DE_Obe = Location(
    "DE-Obe",
    50.78666,
    13.72129,
    "enf",
    "Dfb"
)

CZ_Stn = Location(
    "CZ-Stn",
    49.035975,
    17.9699,
    "dbf",
    "Dfb"
)

SE_Sk2 = Location(
    "SE-Sk2",
    60.12966667,
    17.84005556,
    "enf",
    "Dfb"
)

DE_Bay = Location(
    "DE-Bay",
    50.14194,
    11.86694,
    "enf",
    "Dfb"
)

FI_Hyy = Location(
    "FI-Hyy",
    61.84741,
    24.29477,
    "enf",
    "Dfc"
)

BE_Vie = Location(
    "BE-Vie",
    50.304962,
    5.998099,
    "mf",
    "Cfb"
)

DE_Hzd = Location(
    "DE-Hzd",
    50.96381,
    13.48978,
    "dbf",
    "Dfb"
)

DE_RuW = Location(
    "DE-RuW",
    50.50490703,
    6.33101886,
    "enf",
    "Cfb"
)

SE_Ros = Location(
    "SE-Ros",
    50.50490703,
    6.33101886,
    "enf",
    "Cfb"
)

FR_Pue = Location(
    "FR-Pue",
    43.7413,
    3.5957,
    "enf",
    "Csb"
)

DE_Lkb = Location(
    "DE-Lkb",
    49.09961667,
    13.30466667,
    "enf",
    "Dfb"
)

FI_Let = Location(
    "FI-Let",
    60.64183,
    23.95952,
    "enf",
    "Dfc"
)

IT_La2 = Location(
    "IT-La2",
    45.9542,
    11.2853,
    "enf",
    "Cfa/Dfb/Cfb"
)

IT_Ren = Location(
    "IT-Ren",
    46.58686,
    11.43369,
    "enf",
    "Dfb"
)

SE_Svb = Location(
    "SE-Svb",
    64.25611,
    19.7745,
    "enf",
    "Dfc"
)

DE_Hai = Location(
    "DE-Hai",
    51.079213,
    10.452168,
    "dbf",
    "Dfb"
)

CZ_Lnz = Location(
    "CZ-Lnz",
    48.681611,
    16.946416,
    "mf",
    "Dfb"
)

location_data = [
    IT_Lav,
    SE_Nor,
    DE_Wet,
    CZ_BK1,
    NL_Loo,
    SE_Htm,
    DE_Obe,
    CZ_Stn,
    SE_Sk2,
    DE_Bay,
    FI_Hyy,
    BE_Vie,
    DE_Hzd,
    DE_RuW,
    SE_Ros,
    FR_Pue,
    DE_Lkb,
    FI_Let,
    IT_La2,
    IT_Ren,
    SE_Svb,
    DE_Hai,
    CZ_Lnz
]

ft = []
for l in locations
    push!(ft, l.forest_type)
end